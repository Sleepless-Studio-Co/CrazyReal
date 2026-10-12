import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  Get,
  NotFoundException,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
  UseGuards,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiResponse, ApiConsumes, ApiBody, ApiBearerAuth } from '@nestjs/swagger';
import { PrismaService } from './prisma/prisma.service';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { readdirSync, promises as fs } from 'fs';
import { execFile } from 'child_process';
import { promisify } from 'util';
import { join } from 'path';
import { JwtAuthGuard } from './auth/jwt-auth.guard';
import { CurrentUser } from './auth/current-user.decorator';
import { ChallengeType, MediaType } from '@prisma/client';
import { FeedGateway } from './feed/feed.gateway';
import type { ValidatedUser } from './auth/interfaces/auth-user.interface';
import {
  formatPostWithUpvotes,
  postIncludeWithUpvotes,
} from './posts/post.utils';

const execFileAsync = promisify(execFile);

@ApiTags('CrazyReal')
@ApiBearerAuth('access-token')
@Controller()
@UseGuards(JwtAuthGuard)
export class AppController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly feedGateway: FeedGateway,
  ) {}

  private async getAcceptedFriendIds(userId: number): Promise<number[]> {
    const friendships = await this.prisma.friendship.findMany({
      where: {
        status: 'ACCEPTED',
        OR: [{ userId }, { friendId: userId }],
      },
    });

    return friendships.map((friendship) =>
      friendship.userId === userId ? friendship.friendId : friendship.userId,
    );
  }

  private isChallengeActiveNow(
    challenge: {
      date: Date;
      type: ChallengeType;
      durationHours: number | null;
      endsAt?: Date | null;
      isActive: boolean;
    },
    now: Date,
  ): boolean {
    if (!challenge.isActive) {
      return false;
    }

    const startsAt = new Date(challenge.date);
    const durationHours =
      challenge.durationHours ?? (challenge.type === 'SPECIAL' ? 24 : 84);
    const endsAt =
      challenge.endsAt ??
      new Date(startsAt.getTime() + durationHours * 60 * 60 * 1000);

    return now >= startsAt && now < endsAt;
  }

  private async getCurrentChallengeForDate(now: Date) {
    // Custom durations are limited to one year by the admin DTO.
    const maxDurationMs = 8760 * 60 * 60 * 1000;
    const lookbackDate = new Date(now.getTime() - maxDurationMs);

    const candidateChallenges = await this.prisma.challenge.findMany({
      where: {
        isActive: true,
        // Le "challenge global courant" ne considère que les challenges globaux ;
        // les défis de groupe ont leur propre cycle de vie (fenêtre endsAt).
        conversationId: null,
        date: {
          lte: now,
          gte: lookbackDate,
        },
      },
      orderBy: {
        date: 'desc',
      },
    });

    // Filter active challenges and sort by priority (SPECIAL first, then by date desc)
    const activeChallenges = candidateChallenges
      .filter((challenge) => this.isChallengeActiveNow(challenge, now))
      .sort((a, b) => {
        if (a.type === 'SPECIAL' && b.type !== 'SPECIAL') return -1;
        if (a.type !== 'SPECIAL' && b.type === 'SPECIAL') return 1;
        return b.date.getTime() - a.date.getTime();
      });

    return activeChallenges[0] || null;
  }

  private async getActiveGlobalChallenges(now: Date) {
    const lookbackDate = new Date(now.getTime() - 8760 * 60 * 60 * 1000);
    const challenges = await this.prisma.challenge.findMany({
      where: {
        isActive: true,
        conversationId: null,
        date: { lte: now, gte: lookbackDate },
      },
      orderBy: { date: 'desc' },
    });

    return challenges
      .filter((challenge) => this.isChallengeActiveNow(challenge, now))
      .sort((a, b) => b.date.getTime() - a.date.getTime());
  }

  @Get('challenge/current')
  @ApiOperation({ summary: 'Récupérer le challenge actuel' })
  @ApiResponse({ status: 200, description: 'Challenge récupéré avec succès' })
  async getCurrentChallenge() {
    const now = new Date();

    const currentChallenge = await this.getCurrentChallengeForDate(now);

    if (!currentChallenge) {
      throw new NotFoundException('Aucun challenge global actif n\'a été trouvé pour la date et l\'heure actuelles.');
    }

    return currentChallenge;
  }

  @Get('challenges/available')
  @ApiOperation({ summary: 'Défis réalisables : global courant + défis de mes groupes actifs' })
  async getAvailableChallenges(@CurrentUser() user: ValidatedUser) {
    const now = new Date();

    const globalChallenges = await this.getActiveGlobalChallenges(now);

    const groupChallenges = await this.prisma.challenge.findMany({
      where: {
        conversation: { is: { participants: { some: { userId: user.userId } } } },
        date: { lte: now },
        endsAt: { gt: now },
      },
      include: { conversation: { select: { id: true, name: true } } },
      orderBy: { endsAt: 'asc' },
    });

    return [
      ...globalChallenges.map((global) => ({
            ...global,
            endsAt:
              global.endsAt ??
              new Date(
                global.date.getTime() +
                  (global.durationHours ??
                    (global.type === 'SPECIAL' ? 24 : 84)) *
                    60 *
                    60 *
                    1000,
              ),
            group: null,
          })),
      ...groupChallenges.map(({ conversation, ...c }) => ({
        ...c,
        group: conversation,
      })),
    ];
  }

  // Valide qu'un utilisateur peut poster sur un challenge, et le renvoie.
  // challengeId absent => challenge global courant (rétrocompat caméra).
  private async resolveChallengeForPost(userId: number, challengeId?: number) {
    const now = new Date();

    if (challengeId == null) {
      const current = await this.getCurrentChallengeForDate(now);
      if (!current) {
        throw new BadRequestException('Aucun challenge actif n\'est disponible pour poster en ce moment.');
      }
      return current;
    }

    const challenge = await this.prisma.challenge.findUnique({
      where: { id: challengeId },
    });
    if (!challenge) {
      throw new NotFoundException('Challenge introuvable.');
    }

    if (challenge.conversationId == null) {
      // Challenge global : doit être dans sa fenêtre active.
      if (!this.isChallengeActiveNow(challenge, now)) {
        throw new BadRequestException('Ce challenge global n\'est plus actif.');
      }
      return challenge;
    }

    // Défi de groupe : membre du groupe + fenêtre [date, endsAt] active.
    const isMember = await this.prisma.participant.findUnique({
      where: {
        userId_conversationId: { userId, conversationId: challenge.conversationId },
      },
    });
    if (!isMember) {
      throw new ForbiddenException('Tu ne fais pas partie de ce groupe.');
    }
    if (!challenge.endsAt || challenge.date > now || challenge.endsAt <= now) {
      throw new BadRequestException('Ce défi n\'est plus actif.');
    }
    return challenge;
  }

  private resolveMediaType(mimetype: string, originalname: string): MediaType {
    const extension = extname(originalname || '').toLowerCase();
    const isVideo = (mimetype || '').startsWith('video/') || [
      '.mp4',
      '.mov',
      '.webm',
      '.3gp',
    ].includes(extension);

    if (isVideo) {
      return MediaType.VIDEO;
    }
    return MediaType.PHOTO;
  }

  private async normalizeVideo(file: Express.Multer.File): Promise<void> {
    const normalizedPath = `${file.path}.normalized.mp4`;
    const outputFilename = `${file.filename.replace(extname(file.filename), '')}.mp4`;
    const outputPath = join(file.destination, outputFilename);

    try {
      await execFileAsync('ffmpeg', [
        '-y',
        '-i', file.path,
        '-c:v', 'libx264',
        '-profile:v', 'baseline',
        '-level', '3.1',
        '-preset', 'veryfast',
        '-pix_fmt', 'yuv420p',
        '-c:a', 'aac',
        '-b:a', '128k',
        '-ar', '44100',
        '-ac', '2',
        '-movflags', '+faststart',
        normalizedPath,
      ]);
      await fs.unlink(file.path);
      await fs.rename(normalizedPath, outputPath);
      file.filename = outputFilename;
      file.path = outputPath;
    } catch (error) {
      await fs.unlink(normalizedPath).catch(() => undefined);
      throw new BadRequestException('Unable to process video');
    }
  }

  @Post('posts')
  @ApiOperation({ summary: 'Upload une photo ou vidéo pour le challenge' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: {
          type: 'string',
          format: 'binary',
        },
        challengeId: {
          type: 'string',
          description: 'Challenge visé (global ou défi de groupe). Absent = global courant.',
        },
      },
    },
  })
  @ApiResponse({ status: 201, description: 'Média uploadé avec succès' })
  @UseInterceptors(FileInterceptor('file', {
    // Les vidéos enregistrées en haute résolution dépassent facilement 50 Mo.
    limits: { fileSize: 200 * 1024 * 1024 },
    fileFilter: (_req, file, callback) => {
      const allowedMimeTypes = [
        'image/jpeg',
        'image/png',
        'image/webp',
        'image/heic',
        'image/heif',
        'video/mp4',
        'video/quicktime',
        'video/webm',
        'video/3gpp',
      ];
      const allowedExtensions = [
        '.jpg',
        '.jpeg',
        '.png',
        '.webp',
        '.heic',
        '.heif',
        '.mp4',
        '.mov',
        '.webm',
        '.3gp',
      ];
      const extension = extname(file.originalname).toLowerCase();
      const hasAllowedMimeType = allowedMimeTypes.includes(file.mimetype);
      const hasAllowedExtension = allowedExtensions.includes(extension);

      if (!hasAllowedMimeType && !hasAllowedExtension) {
        callback(new Error('Unsupported media type'), false);
        return;
      }
      callback(null, true);
    },
    storage: diskStorage({
      destination: './uploads',
      filename: (req, file, callback) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const originalExtension = extname(file.originalname).toLowerCase();
        const isVideo = file.mimetype.startsWith('video/') || [
          '.mp4',
          '.mov',
          '.webm',
          '.3gp',
        ].includes(originalExtension);
        const prefix = isVideo ? 'video' : 'image';
        const extension = isVideo ? '.mp4' : '.jpg';
        callback(null, `${prefix}-${uniqueSuffix}${extension}`);
      },
    }),
  }))
  async uploadPhoto(@UploadedFile() file: Express.Multer.File, @CurrentUser() user: any) {
    if (!file) {
      throw new BadRequestException('No file provided');
    }

    const mediaType = this.resolveMediaType(file.mimetype, file.originalname);
    try {
      if (mediaType === MediaType.VIDEO) {
        await this.normalizeVideo(file);
      }

      const currentChallenge = await this.getCurrentChallengeForDate(new Date());
      if (!currentChallenge) {
        throw new BadRequestException('Aucun challenge actif n\'est disponible pour poster en ce moment.');
      }

      const post = await this.prisma.post.create({
        data: {
          photoUrl: `/uploads/${file.filename}`,
          mediaType,
          challengeId: currentChallenge.id,
          userId: user.userId,
        },
        include: postIncludeWithUpvotes(user.userId),
      });

      const formattedPost = formatPostWithUpvotes(post);
      // Le feed global temps réel ne reçoit que les posts globaux ; les posts de
    // défis de groupe restent dans le feed privé du groupe (rafraîchi au pull).
      if (currentChallenge.conversationId == null) {
      this.feedGateway.broadcastNewPost(formattedPost);
      console.log('[posts] created', post.id, file.filename, mediaType);
      }

      return formattedPost;
    } catch (error) {
      await fs.unlink(file.path).catch(() => undefined);
      console.error('[posts] upload failed', error);
      throw error;
    }
  }

  @Get('posts')
  @ApiOperation({ summary: 'Récupérer les posts du feed (amis + soi)' })
  @ApiResponse({ status: 200, description: 'Posts récupérés avec succès' })
  async getPosts(
    @CurrentUser() user: ValidatedUser,
    @Query('challengeId') challengeIdRaw?: string,
  ) {
    const friendIds = await this.getAcceptedFriendIds(user.userId);
    const feedUserIds = [...new Set([...friendIds, user.userId])];

    const now = new Date();
    const globalChallenges = await this.getActiveGlobalChallenges(now);
    const groupChallenges = await this.prisma.challenge.findMany({
      where: {
        conversation: { is: { participants: { some: { userId: user.userId } } } },
        date: { lte: now },
        endsAt: { gt: now },
      },
      orderBy: { date: 'desc' },
    });
    const selectableChallengeIds = [
      ...globalChallenges.map((challenge) => challenge.id),
      ...groupChallenges.map((challenge) => challenge.id),
    ];
    const allModeChallengeIds = [
      ...globalChallenges.slice(0, 2).map((challenge) => challenge.id),
      ...groupChallenges.slice(0, 2).map((challenge) => challenge.id),
    ];

    let challengeIds = allModeChallengeIds;
    if (challengeIdRaw != null && challengeIdRaw !== 'all') {
      const challengeId = Number(challengeIdRaw);
      if (!Number.isInteger(challengeId)) {
        throw new BadRequestException('challengeId invalide.');
      }
      if (!selectableChallengeIds.includes(challengeId)) {
        throw new BadRequestException('Ce défi n\'est pas visible dans le feed.');
      }
      challengeIds = [challengeId];
    }

    const posts = await this.prisma.post.findMany({
      where: {
        userId: { in: feedUserIds },
        challengeId: { in: challengeIds },
      },
      orderBy: {
        createdAt: 'desc',
      },
      include: postIncludeWithUpvotes(user.userId),
    });

    return posts.map(formatPostWithUpvotes);
  }
}

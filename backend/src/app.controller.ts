import {
  BadRequestException,
  Controller,
  Get,
  NotFoundException,
  Post,
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
import { I18n, I18nContext } from 'nestjs-i18n';
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
    challenge: { date: Date; type: ChallengeType; isActive: boolean },
    now: Date,
  ): boolean {
    if (!challenge.isActive) {
      return false;
    }

    const startsAt = new Date(challenge.date);
    const durationHours = challenge.type === 'SPECIAL' ? 24 : 84;
    const endsAt = new Date(startsAt.getTime() + durationHours * 60 * 60 * 1000);

    return now >= startsAt && now < endsAt;
  }

  private async getCurrentChallengeForDate(now: Date) {
    // Maximum challenge duration is 84 hours (WEEKLY), so look back that far
    const maxDurationMs = 84 * 60 * 60 * 1000;
    const lookbackDate = new Date(now.getTime() - maxDurationMs);

    const candidateChallenges = await this.prisma.challenge.findMany({
      where: {
        isActive: true,
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

  @Get('challenge/current')
  @ApiOperation({ summary: 'Récupérer le challenge actuel' })
  @ApiResponse({ status: 200, description: 'Challenge récupéré avec succès' })
  async getCurrentChallenge(@I18n() i18n: I18nContext) {
    const now = new Date();

    const currentChallenge = await this.getCurrentChallengeForDate(now);

    if (!currentChallenge) {
      throw new NotFoundException(await i18n.t('challenge.not_found') || 'Aucun challenge global actif n\'a été trouvé pour la date et l\'heure actuelles.');
    }

    return currentChallenge;
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
  async uploadPhoto(@UploadedFile() file: Express.Multer.File, @CurrentUser() user: any, @I18n() i18n: I18nContext) {
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
        throw new BadRequestException(
          await i18n.t('challenge.not_active') ||
            'Aucun challenge actif n\'est disponible pour poster en ce moment.',
        );
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
      this.feedGateway.broadcastNewPost(formattedPost);
      console.log('[posts] created', post.id, file.filename, mediaType);
      return formattedPost;
    } catch (error) {
      await fs.unlink(file.path).catch(() => undefined);
      console.error('[posts] upload failed', error);
      throw error;
    }
  }

  @Get('uploads')
  async getUploads() {
    const uploadsDir = join(process.cwd(), 'uploads');
    const files = readdirSync(uploadsDir);
    return { files: files.map(file => `/uploads/${file}`) };
  }

  @Get('posts')
  @ApiOperation({ summary: 'Récupérer les posts du feed (amis + soi)' })
  @ApiResponse({ status: 200, description: 'Posts récupérés avec succès' })
  async getPosts(@CurrentUser() user: ValidatedUser) {
    const friendIds = await this.getAcceptedFriendIds(user.userId);
    const feedUserIds = [...new Set([...friendIds, user.userId])];

    const posts = await this.prisma.post.findMany({
      where: {
        userId: { in: feedUserIds },
      },
      orderBy: {
        createdAt: 'desc',
      },
      include: postIncludeWithUpvotes(user.userId),
    });

    return posts.map(formatPostWithUpvotes);
  }
}

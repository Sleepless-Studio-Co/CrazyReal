import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
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
import { JwtAuthGuard } from './auth/jwt-auth.guard';
import { CurrentUser } from './auth/current-user.decorator';
import { ChallengeType } from '@prisma/client';
import { FeedGateway } from './feed/feed.gateway';
import type { ValidatedUser } from './auth/interfaces/auth-user.interface';
import {
  formatPostWithUpvotes,
  postIncludeWithUpvotes,
} from './posts/post.utils';

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

    const global = await this.getCurrentChallengeForDate(now);

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
      ...(global ? [{ ...global, group: null }] : []),
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

  @Post('posts')
  @ApiOperation({ summary: 'Upload une photo pour le challenge' })
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
  @ApiResponse({ status: 201, description: 'Photo uploadée avec succès' })
  @UseInterceptors(FileInterceptor('file', {
    storage: diskStorage({
      destination: './uploads',
      filename: (req, file, callback) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = extname(file.originalname);
        callback(null, `image-${uniqueSuffix}${ext}`);
      },
    }),
  }))
  async uploadPhoto(
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: ValidatedUser,
    @Body('challengeId') challengeIdRaw?: string,
  ) {
    const challengeId = challengeIdRaw ? Number(challengeIdRaw) : undefined;
    if (challengeIdRaw && Number.isNaN(challengeId!)) {
      throw new BadRequestException('challengeId invalide.');
    }

    const challenge = await this.resolveChallengeForPost(user.userId, challengeId);

    const post = await this.prisma.post.create({
      data: {
        photoUrl: `/uploads/${file.filename}`,
        challengeId: challenge.id,
        userId: user.userId,
      },
      include: postIncludeWithUpvotes(user.userId),
    });

    const formattedPost = formatPostWithUpvotes(post);

    // Le feed global temps réel ne reçoit que les posts globaux ; les posts de
    // défis de groupe restent dans le feed privé du groupe (rafraîchi au pull).
    if (challenge.conversationId == null) {
      this.feedGateway.broadcastNewPost(formattedPost);
    }

    return formattedPost;
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
        // Feed global : uniquement les posts de challenges globaux.
        // Les posts de défis de groupe restent privés au groupe.
        challenge: { is: { conversationId: null } },
      },
      orderBy: {
        createdAt: 'desc',
      },
      include: postIncludeWithUpvotes(user.userId),
    });

    return posts.map(formatPostWithUpvotes);
  }
}

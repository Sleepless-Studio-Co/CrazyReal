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
import { readdirSync } from 'fs';
import { join } from 'path';
import { I18n, I18nContext } from 'nestjs-i18n';
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
  async uploadPhoto(@UploadedFile() file: Express.Multer.File, @CurrentUser() user: any, @I18n() i18n: I18nContext) {
    console.log(await i18n.t('common.loading'), file.filename);

    const now = new Date();
    const currentChallenge = await this.getCurrentChallengeForDate(now);

    if (!currentChallenge) {
      throw new BadRequestException(await i18n.t('challenge.not_active') || 'Aucun challenge actif n\'est disponible pour poster en ce moment.');
    }

    const post = await this.prisma.post.create({
      data: {
        photoUrl: `/uploads/${file.filename}`,
        challengeId: currentChallenge.id,
        userId: user.userId,
      },
      include: postIncludeWithUpvotes(user.userId),
    });

    const formattedPost = formatPostWithUpvotes(post);

    this.feedGateway.broadcastNewPost(formattedPost);

    return formattedPost;
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

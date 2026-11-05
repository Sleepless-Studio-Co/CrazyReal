import {
  Controller,
  Get,
  NotFoundException,
  Param,
  Post as HttpPost,
  UseGuards,
} from '@nestjs/common';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { postInclude } from '../posts/post.utils';
import type { ValidatedUser } from '../auth/interfaces/auth-user.interface';

const SHARE_LINK_TTL_DAYS = 30;

@Controller('shares')
export class ShareController {
  constructor(private readonly prisma: PrismaService) {}

  @HttpPost('posts/:postId')
  @UseGuards(JwtAuthGuard)
  async create(
    @Param('postId') postIdRaw: string,
    @CurrentUser() user: ValidatedUser,
  ) {
    const postId = Number(postIdRaw);
    if (!Number.isInteger(postId)) {
      throw new NotFoundException('Post introuvable.');
    }

    const post = await this.prisma.post.findFirst({
      where: {
        id: postId,
        OR: [
          { userId: user.userId },
          { challenge: { conversationId: null } },
        ],
      },
      select: { id: true },
    });
    if (!post) {
      throw new NotFoundException('Post introuvable.');
    }

    const token = randomBytes(32).toString('base64url');
    const expiresAt = new Date(
      Date.now() + SHARE_LINK_TTL_DAYS * 24 * 60 * 60 * 1000,
    );
    await this.prisma.shareLink.create({
      data: { token, postId: post.id, expiresAt },
    });

    return { token, expiresAt };
  }

  @Get(':token/feed')
  async getGuestFeed(@Param('token') token: string) {
    const share = await this.prisma.shareLink.findFirst({
      where: { token, expiresAt: { gt: new Date() } },
      include: {
        post: {
          include: postInclude,
        },
      },
    });
    if (!share) {
      throw new NotFoundException('Ce lien de partage est invalide ou expiré.');
    }

    const globalPosts = await this.prisma.post.findMany({
      where: {
        challenge: { conversationId: null },
        id: { not: share.postId },
      },
      orderBy: { createdAt: 'desc' },
      take: 1,
      include: postInclude,
    });

    return [share.post, ...globalPosts].map((post) => ({
      ...post,
      upvoteCount: 0,
      hasUpvoted: false,
    }));
  }
}

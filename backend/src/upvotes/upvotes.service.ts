import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  formatPostWithUpvotes,
  postIncludeWithUpvotes,
} from '../posts/post.utils';
import { PostModerationStatus } from '@prisma/client';

@Injectable()
export class UpVotesService {
  constructor(private readonly prisma: PrismaService) {}

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

  private async assertPostInFeed(userId: number, postId: number) {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      select: { id: true, userId: true, user: { select: { isPrivate: true } } },
    });

    if (!post) {
      throw new NotFoundException('Post introuvable.');
    }

    if (post.userId === userId || !post.user.isPrivate) {
      return post;
    }

    const friendIds = await this.getAcceptedFriendIds(userId);
    if (!friendIds.includes(post.userId)) {
      throw new NotFoundException('Post introuvable.');
    }

    return post;
  }

  private async getFormattedPost(postId: number, userId: number) {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      include: postIncludeWithUpvotes(userId),
    });

    if (!post) {
      throw new NotFoundException('Post introuvable.');
    }

    return formatPostWithUpvotes(post, userId);
  }

  async upvote(userId: number, postId: number) {
    await this.assertPostInFeed(userId, postId);

    try {
      await this.prisma.upVote.create({
        data: { userId, postId },
      });
    } catch (error: unknown) {
      // P2002 = already upvoted; treat as a no-op (idempotent).
      if (
        !(
          error &&
          typeof error === 'object' &&
          'code' in error &&
          error.code === 'P2002'
        )
      ) {
        throw error;
      }
    }

    return this.getFormattedPost(postId, userId);
  }

  async removeUpvote(userId: number, postId: number) {
    await this.assertPostInFeed(userId, postId);

    const existing = await this.prisma.upVote.findUnique({
      where: { userId_postId: { userId, postId } },
    });

    if (!existing) {
      throw new BadRequestException("Tu n'as pas voté pour ce post.");
    }

    await this.prisma.upVote.delete({
      where: { userId_postId: { userId, postId } },
    });

    return this.getFormattedPost(postId, userId);
  }

  async addReaction(userId: number, postId: number, emoji: string) {
    await this.assertPostInFeed(userId, postId);
    await this.prisma.$transaction([
      this.prisma.postReaction.deleteMany({
        where: { userId, postId },
      }),
      this.prisma.postReaction.create({
        data: { userId, postId, emoji },
      }),
    ]);
    return this.getFormattedPost(postId, userId);
  }

  async removeReaction(userId: number, postId: number, emoji: string) {
    await this.assertPostInFeed(userId, postId);
    await this.prisma.postReaction.deleteMany({
      where: { userId, postId, emoji },
    });
    return this.getFormattedPost(postId, userId);
  }

  async reportPost(userId: number, postId: number) {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      select: { id: true, isGhosted: true },
    });
    if (!post) throw new NotFoundException('Post introuvable.');

    await this.prisma.postReport.upsert({
      where: { userId_postId: { userId, postId } },
      create: { userId, postId },
      update: {},
    });

    const reportCount = await this.prisma.postReport.count({ where: { postId } });
    if (reportCount >= 5 && !post.isGhosted) {
      await this.prisma.post.update({
        where: { id: postId },
        data: {
          isGhosted: true,
          moderationStatus: PostModerationStatus.GHOSTED,
        },
      });
    }

    return { reported: true, reportCount, isGhosted: reportCount >= 5 || post.isGhosted };
  }
}

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
      select: { id: true, userId: true },
    });

    if (!post) {
      throw new NotFoundException('Post introuvable.');
    }

    if (post.userId === userId) {
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

    return formatPostWithUpvotes(post);
  }

  async upvote(userId: number, postId: number) {
    await this.assertPostInFeed(userId, postId);

    const existing = await this.prisma.upVote.findUnique({
      where: { userId_postId: { userId, postId } },
    });

    if (existing) {
      return this.getFormattedPost(postId, userId);
    }

    try {
      await this.prisma.upVote.create({
        data: { userId, postId },
      });
    } catch (error: unknown) {
      if (
        error &&
        typeof error === 'object' &&
        'code' in error &&
        error.code === 'P2002'
      ) {
        return this.getFormattedPost(postId, userId);
      }
      throw error;
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
}

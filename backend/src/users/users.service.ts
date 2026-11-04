import {
  ConflictException,
  ForbiddenException,
  HttpException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { StreakService } from '../streak/streak.service';
import {
  formatPostWithUpvotes,
  postIncludeWithUpvotes,
} from '../posts/post.utils';
import * as bcrypt from 'bcrypt';

const USER_SELECT = {
  id: true,
  email: true,
  username: true,
  avatarUrl: true,
  avatarKey: true,
  isPrivate: true,
  createdAt: true,
} as const;

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly streakService: StreakService,
  ) {}

  private handlePrismaError(error: unknown): never {
    if (error instanceof HttpException) {
      throw error;
    }

    if (error instanceof Prisma.PrismaClientKnownRequestError) {
      if (error.code === 'P2002') {
        const target = error.meta?.target;
        const fields = Array.isArray(target)
          ? target.join(',')
          : String(target ?? '');

        if (fields.includes('email')) {
          throw new ConflictException('mail already in use');
        }

        if (fields.includes('username')) {
          throw new ConflictException('username already in use');
        }

        throw new ConflictException('unique constraint violation');
      }

      if (error.code === 'P2025') {
        throw new NotFoundException('user not found');
      }
    }

    throw new InternalServerErrorException('Database operation failed');
  }

  async create(email: string, password: string, username: string) {
    try {
      const hashedPassword = await bcrypt.hash(password, 10);

      return await this.prisma.user.create({
        data: {
          email,
          password: hashedPassword,
          username,
        },
        select: {
          id: true,
          email: true,
          username: true,
          avatarUrl: true,
          avatarKey: true,
          isPrivate: true,
          emailVerified: true,
          createdAt: true,
        },
      });
    } catch (error) {
      this.handlePrismaError(error);
    }
  }

  async findByEmail(email: string) {
    try {
      return await this.prisma.user.findUnique({
        where: { email },
        select: {
          id: true,
          email: true,
          username: true,
          avatarUrl: true,
          avatarKey: true,
          isPrivate: true,
          emailVerified: true,
          createdAt: true,
        },
      });
    } catch (error) {
      this.handlePrismaError(error);
    }
  }

  async findByEmailWithPassword(email: string) {
    try {
      return await this.prisma.user.findUnique({
        where: { email },
        select: {
          id: true,
          email: true,
          username: true,
          password: true,
          avatarUrl: true,
          avatarKey: true,
          isPrivate: true,
          emailVerified: true,
          createdAt: true,
        },
      });
    } catch (error) {
      this.handlePrismaError(error);
    }
  }

  async findById(id: number) {
    try {
      return await this.prisma.user.findUnique({
        where: { id },
        select: {
          id: true,
          email: true,
          username: true,
          avatarUrl: true,
          avatarKey: true,
          isPrivate: true,
          emailVerified: true,
          createdAt: true,
          role: true,
        },
      });
    } catch (error) {
      this.handlePrismaError(error);
    }
  }

  async findAll() {
    try {
      return this.prisma.user.findMany({
        select: {
          id: true,
          email: true,
          username: true,
          avatarUrl: true,
          avatarKey: true,
          isPrivate: true,
          emailVerified: true,
          createdAt: true,
        },
      });
    } catch (error) {
      this.handlePrismaError(error);
    }
  }

  async searchByUsername(query: string, requesterId: number) {
    try {
      return this.prisma.user.findMany({
        where: {
          username: { contains: query, mode: 'insensitive' },
          NOT: { id: requesterId },
        },
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          avatarKey: true,
          isPrivate: true,
        },
        orderBy: { username: 'asc' },
        take: 20,
      });
    } catch (error) {
      this.handlePrismaError(error);
    }
  }

  async updateProfile(
    userId: number,
    updates: {
      email?: string;
      username?: string;
      emailVerified?: boolean;
      emailVerifiedAt?: Date | null;
    },
  ) {
    try {
      return await this.prisma.user.update({
        where: { id: userId },
        data: updates,
        select: {
          id: true,
          email: true,
          username: true,
          avatarUrl: true,
          avatarKey: true,
          isPrivate: true,
          emailVerified: true,
          createdAt: true,
        },
      });
    } catch (error) {
      this.handlePrismaError(error);
    }
  }

  async updateAvatar(
    userId: number,
    updates: { avatarUrl?: string | null; avatarKey?: string | null },
  ) {
    try {
      return await this.prisma.user.update({
        where: { id: userId },
        data: updates,
        select: {
          id: true,
          email: true,
          username: true,
          avatarUrl: true,
          avatarKey: true,
          isPrivate: true,
          emailVerified: true,
          createdAt: true,
        },
      });
    } catch (error) {
      this.handlePrismaError(error);
    }
  }

  async updatePrivacy(userId: number, isPrivate: boolean) {
    try {
      return await this.prisma.user.update({
        where: { id: userId },
        data: { isPrivate },
        select: {
          id: true,
          email: true,
          username: true,
          avatarUrl: true,
          avatarKey: true,
          isPrivate: true,
          emailVerified: true,
          createdAt: true,
        },
      });
    } catch (error) {
      this.handlePrismaError(error);
    }
  }

  async deleteAccount(userId: number) {
    try {
      // Dependent rows (posts, messages, participants, friendships, upvotes,
      // refresh tokens) are removed by ON DELETE CASCADE at the DB level.
      await this.prisma.user.delete({ where: { id: userId } });
    } catch (error) {
      this.handlePrismaError(error);
    }
  }

  private async getProfileVisibility(targetId: number, requesterId: number) {
    const target = await this.prisma.user.findUnique({
      where: { id: targetId },
      select: {
        id: true,
        username: true,
        avatarUrl: true,
        avatarKey: true,
        isPrivate: true,
        createdAt: true,
      },
    });

    if (!target) {
      throw new NotFoundException('user not found');
    }

    const isSelf = target.id === requesterId;
    const friendship = isSelf
      ? null
      : await this.prisma.friendship.findFirst({
          where: {
            status: 'ACCEPTED',
            OR: [
              { userId: requesterId, friendId: targetId },
              { userId: targetId, friendId: requesterId },
            ],
          },
        });
    const isFriend = Boolean(friendship);

    return {
      target,
      isSelf,
      isFriend,
      canViewContent: isSelf || !target.isPrivate || isFriend,
    };
  }

  private async getProfileExtras(userId: number) {
    const [streak, postsCount] = await Promise.all([
      this.streakService.getStreakForUser(userId),
      this.prisma.post.count({
        where: {
          userId,
          challenge: { is: { conversationId: null } },
        },
      }),
    ]);

    return {
      streak,
      stats: {
        postsCount,
        challengesCount: streak.participatedEditions,
      },
    };
  }

  async findPublicProfile(targetId: number, requesterId: number) {
    try {
      const { target, isSelf, isFriend, canViewContent } =
        await this.getProfileVisibility(targetId, requesterId);

      if (!canViewContent) {
        return {
          id: target.id,
          username: target.username,
          avatarUrl: target.avatarUrl,
          avatarKey: target.avatarKey,
          isPrivate: true,
          isFriend: false,
          isSelf: false,
          canViewContent: false,
        };
      }

      const extras = await this.getProfileExtras(target.id);

      return {
        ...target,
        isFriend: isSelf ? true : isFriend,
        isSelf,
        canViewContent: true,
        ...extras,
      };
    } catch (error) {
      this.handlePrismaError(error);
    }
  }

  async findPublicPosts(
    targetId: number,
    requesterId: number,
    limit = 30,
    cursor?: number,
  ) {
    try {
      const { canViewContent } = await this.getProfileVisibility(
        targetId,
        requesterId,
      );

      if (!canViewContent) {
        throw new ForbiddenException('This account is private.');
      }

      const take = Math.min(Math.max(limit, 1), 50);
      const posts = await this.prisma.post.findMany({
        where: {
          userId: targetId,
          // Group challenge posts stay private to their conversation.
          challenge: { is: { conversationId: null } },
        },
        orderBy: { createdAt: 'desc' },
        take: take + 1,
        ...(cursor !== undefined && cursor > 0
          ? { cursor: { id: cursor }, skip: 1 }
          : {}),
        include: postIncludeWithUpvotes(requesterId),
      });

      const hasMore = posts.length > take;
      const visiblePosts = hasMore ? posts.slice(0, take) : posts;

      return {
        items: visiblePosts.map((post) =>
          formatPostWithUpvotes(post, requesterId),
        ),
        nextCursor: hasMore ? visiblePosts[visiblePosts.length - 1].id : null,
      };
    } catch (error) {
      this.handlePrismaError(error);
    }
  }
}

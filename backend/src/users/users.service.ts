import {
  ConflictException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';
import {
  formatPostWithUpvotes,
  postIncludeWithUpvotes,
} from '../posts/post.utils';

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
  constructor(private readonly prisma: PrismaService) {}

  private handlePrismaError(error: unknown): never {
    if (error instanceof Prisma.PrismaClientKnownRequestError) {
      if (error.code === 'P2002') {
        const target = error.meta?.target;
        const fields = Array.isArray(target) ? target.join(',') : String(target ?? '');

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

  async findPublicProfile(targetId: number, requesterId: number) {
    try {
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
      const isFriend =
        isSelf ||
        (await this.prisma.friendship.count({
          where: {
            status: 'ACCEPTED',
            OR: [
              { userId: requesterId, friendId: targetId },
              { userId: targetId, friendId: requesterId },
            ],
          },
        })) > 0;
      // ponytail: "abonnés" = amis acceptés, the app has no follow model.
      const friendCount = await this.prisma.friendship.count({
        where: {
          status: 'ACCEPTED',
          OR: [{ userId: targetId }, { friendId: targetId }],
        },
      });

      if (target.isPrivate && !isFriend) {
        return {
          id: target.id,
          username: target.username,
          avatarUrl: target.avatarUrl,
          avatarKey: target.avatarKey,
          isPrivate: true,
          isFriend: false,
          isSelf: false,
          friendCount,
          posts: [],
        };
      }

      // Group-challenge posts stay inside their group feed.
      const posts = await this.prisma.post.findMany({
        where: { userId: targetId, challenge: { conversationId: null } },
        orderBy: { createdAt: 'desc' },
        include: postIncludeWithUpvotes(requesterId),
      });

      return {
        ...target,
        isFriend,
        isSelf,
        friendCount,
        posts: posts.map(formatPostWithUpvotes),
      };
    } catch (error) {
      if (error instanceof NotFoundException) throw error;
      this.handlePrismaError(error);
    }
  }
}

import {
  ConflictException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';

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

      return this.prisma.user.create({
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
      return this.prisma.user.findUnique({
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
      return this.prisma.user.findUnique({
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
      return this.prisma.user.findUnique({
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
      return this.prisma.user.update({
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
      return this.prisma.user.update({
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
      return this.prisma.user.update({
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

      if (target.id === requesterId) {
        return { ...target, isFriend: true, isSelf: true };
      }

      if (!target.isPrivate) {
        return { ...target, isFriend: false, isSelf: false };
      }

      const friendship = await this.prisma.friendship.findFirst({
        where: {
          status: 'ACCEPTED',
          OR: [
            { userId: requesterId, friendId: targetId },
            { userId: targetId, friendId: requesterId },
          ],
        },
      });

      if (friendship) {
        return { ...target, isFriend: true, isSelf: false };
      }

      return {
        id: target.id,
        username: target.username,
        avatarUrl: target.avatarUrl,
        avatarKey: target.avatarKey,
        isPrivate: true,
        isFriend: false,
        isSelf: false,
      };
    } catch (error) {
      this.handlePrismaError(error);
    }
  }
}

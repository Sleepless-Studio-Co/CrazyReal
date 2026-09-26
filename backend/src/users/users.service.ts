import {
  ConflictException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
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

  async findByGoogleId(googleId: string) {
    try {
      return await this.prisma.user.findUnique({
        where: { googleId },
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

  async findByUsername(username: string) {
    try {
      return await this.prisma.user.findUnique({
        where: { username },
        select: { id: true },
      });
    } catch (error) {
      this.handlePrismaError(error);
    }
  }

  /** Builds a unique username close to [base] by appending a numeric suffix. */
  async generateUniqueUsername(base: string): Promise<string> {
    const sanitized =
      base
        .toLowerCase()
        .replace(/[^a-z0-9_.]/g, '')
        .slice(0, 20) || 'user';

    let candidate = sanitized;
    let suffix = 1;
    while (await this.findByUsername(candidate)) {
      suffix += 1;
      const suffixText = String(suffix);
      candidate = `${sanitized.slice(0, 24 - suffixText.length)}${suffixText}`;
    }
    return candidate;
  }

  /**
   * Creates a password-less account for a user signing in with Google.
   * Google has already verified the email address, so it is marked verified.
   */
  async createGoogleUser(params: {
    email: string;
    username: string;
    googleId: string;
    avatarUrl?: string | null;
  }) {
    try {
      const username = await this.generateUniqueUsername(params.username);
      return await this.prisma.user.create({
        data: {
          email: params.email,
          username,
          googleId: params.googleId,
          avatarUrl: params.avatarUrl ?? null,
          emailVerified: true,
          emailVerifiedAt: new Date(),
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

  /** Links an existing password account to a Google account. */
  async linkGoogleAccount(
    userId: number,
    updates: { googleId: string; avatarUrl?: string | null },
  ) {
    try {
      const existing = await this.findById(userId);

      const data: Prisma.UserUpdateInput = {
        googleId: updates.googleId,
        emailVerified: true,
        emailVerifiedAt: new Date(),
      };

      // Only adopt the Google picture when the user has no avatar yet.
      if (!existing?.avatarUrl && updates.avatarUrl) {
        data.avatarUrl = updates.avatarUrl;
      }

      return await this.prisma.user.update({
        where: { id: userId },
        data,
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

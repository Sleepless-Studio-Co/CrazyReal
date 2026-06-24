import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../users/users.service';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';
import { JwtPayload } from './interfaces/jwt-payload.interface';
import { AuthUser, AuthUserWithPassword } from './interfaces/auth-user.interface';
import { EmailVerificationService } from './email-verification.service';

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
    private configService: ConfigService,
    private prisma: PrismaService,
    private emailVerificationService: EmailVerificationService,
  ) {}

  async validateUser(email: string, password: string): Promise<AuthUser | null> {
    const user: AuthUserWithPassword | null = await this.usersService.findByEmailWithPassword(email);
    if (!user) {
      return null;
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return null;
    }

    const { password: _password, ...result } = user;
    return result;
  }

  private async generateRefreshToken(userId: number): Promise<string> {
    const token = randomBytes(64).toString('hex');
    const expirationDays = parseInt(this.configService.get<string>('JWT_REFRESH_EXPIRATION') || '30', 10);
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + expirationDays);

    await this.prisma.refreshToken.create({
      data: {
        token,
        userId,
        expiresAt,
      },
    });

    return token;
  }

  private generateAccessToken(user: Pick<AuthUser, 'id' | 'email' | 'username'>): string {
    const payload: JwtPayload = { email: user.email, sub: user.id, username: user.username };
    return this.jwtService.sign(payload);
  }

  async register(email: string, password: string, username: string) {
    const existingUser = await this.usersService.findByEmail(email);
    if (existingUser) {
      throw new ConflictException('mail already in use');
    }

    try {
      const newUser = await this.usersService.create(email, password, username);

      // Fire off the verification email. Failures are handled inside the
      // service so a mail outage never blocks account creation.
      await this.emailVerificationService.createAndSend({
        id: newUser.id,
        email: newUser.email,
        username: newUser.username,
      });

      const accessToken = this.generateAccessToken(newUser);
      const refreshToken = await this.generateRefreshToken(newUser.id);

      return {
        access_token: accessToken,
        refresh_token: refreshToken,
        user: {
          id: newUser.id,
          email: newUser.email,
          username: newUser.username,
          avatarUrl: newUser.avatarUrl,
          avatarKey: newUser.avatarKey,
          emailVerified: newUser.emailVerified,
        },
      };
    } catch (error) {
      // Handle Prisma unique constraint violation (P2002)
      if (error.code === 'P2002') {
        throw new ConflictException('mail already in use');
      }
      // Re-throw other errors
      throw error;
    }
  }

  async login(email: string, password: string) {
    const user = await this.validateUser(email, password);

    if (!user) {
      throw new UnauthorizedException('Email ou mot de passe incorrect');
    }

    const accessToken = this.generateAccessToken(user);
    const refreshToken = await this.generateRefreshToken(user.id);

    return {
      access_token: accessToken,
      refresh_token: refreshToken,
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        avatarUrl: user.avatarUrl,
        avatarKey: user.avatarKey,
        emailVerified: user.emailVerified,
      },
    };
  }

  async getMe(userId: number) {
    const user = await this.usersService.findById(userId);
    if (!user) {
      throw new UnauthorizedException('User not found');
    }
    return {
      id: user.id,
      email: user.email,
      username: user.username,
      avatarUrl: user.avatarUrl,
      avatarKey: user.avatarKey,
      emailVerified: user.emailVerified,
      createdAt: user.createdAt,
    };
  }

  async verifyEmail(token: string) {
    return this.emailVerificationService.verify(token);
  }

  async resendVerificationEmail(userId: number) {
    await this.emailVerificationService.resendForUser(userId);
    return { message: 'Verification email sent' };
  }

  async refresh(refreshToken: string) {
    const tokenRecord = await this.prisma.refreshToken.findUnique({
      where: { token: refreshToken },
      include: { user: true },
    });

    if (!tokenRecord || tokenRecord.isRevoked) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    if (new Date() > tokenRecord.expiresAt) {
      throw new UnauthorizedException('Refresh token expired');
    }

    const accessToken = this.generateAccessToken(tokenRecord.user);

    return {
      access_token: accessToken,
    };
  }

  async revokeRefreshToken(token: string) {
    await this.prisma.refreshToken.updateMany({
      where: { token },
      data: { isRevoked: true },
    });
  }

  async updateProfile(
    userId: number,
    updates: { email?: string; username?: string },
  ) {
    const normalizedEmail =
      typeof updates.email === 'string' ? updates.email.trim() : undefined;
    const normalizedUsername =
      typeof updates.username === 'string' ? updates.username.trim() : undefined;

    const payload: {
      email?: string;
      username?: string;
      emailVerified?: boolean;
      emailVerifiedAt?: Date | null;
    } = {};

    let emailChanged = false;

    if (normalizedEmail) {
      if (!this.isValidEmail(normalizedEmail)) {
        throw new BadRequestException('Invalid email');
      }
      const current = await this.usersService.findById(userId);
      if (current && current.email !== normalizedEmail) {
        payload.email = normalizedEmail;
        // A new address has to be re-verified.
        payload.emailVerified = false;
        payload.emailVerifiedAt = null;
        emailChanged = true;
      }
    }

    if (normalizedUsername) {
      if (normalizedUsername.length < 3) {
        throw new BadRequestException('Username too short');
      }
      payload.username = normalizedUsername;
    }

    if (Object.keys(payload).length === 0) {
      throw new BadRequestException('No changes provided');
    }

    const updatedUser = await this.usersService.updateProfile(userId, payload);

    if (emailChanged) {
      await this.emailVerificationService.createAndSend({
        id: updatedUser.id,
        email: updatedUser.email,
        username: updatedUser.username,
      });
    }

    const accessToken = this.generateAccessToken(updatedUser);

    return {
      access_token: accessToken,
      user: {
        id: updatedUser.id,
        email: updatedUser.email,
        username: updatedUser.username,
        avatarUrl: updatedUser.avatarUrl,
        avatarKey: updatedUser.avatarKey,
        emailVerified: updatedUser.emailVerified,
      },
    };
  }

  private isValidEmail(email: string): boolean {
    return /^[^@]+@[^@]+\.[^@]+$/.test(email);
  }
}

import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../users/users.service';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
    private configService: ConfigService,
    private prisma: PrismaService,
  ) {}

  async validateUser(email: string, password: string): Promise<any> {
    const user = await this.usersService.findByEmailWithPassword(email);
    if (!user) {
      return null;
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return null;
    }

    const { password: _, ...result } = user;
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

  private generateAccessToken(user: any): string {
    const payload = { email: user.email, sub: user.id, username: user.username };
    return this.jwtService.sign(payload);
  }

  async register(email: string, password: string, username: string) {
    const existingUser = await this.usersService.findByEmail(email);
    if (existingUser) {
      throw new ConflictException('mail already in use');
    }

    try {
      const newUser = await this.usersService.create(email, password, username);

      const accessToken = this.generateAccessToken(newUser);
      const refreshToken = await this.generateRefreshToken(newUser.id);

      return {
        access_token: accessToken,
        refresh_token: refreshToken,
        user: {
          id: newUser.id,
          email: newUser.email,
          username: newUser.username,
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
      },
    };
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
}

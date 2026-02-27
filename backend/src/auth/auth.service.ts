import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UsersService } from '../users/users.service';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
  ) {}

  async validateUser(email: string, password: string): Promise<any> {
    const user = await this.usersService.findByEmail(email);
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

  async register(email: string, password: string, username: string) {
    const existingUser = await this.usersService.findByEmail(email);
    if (existingUser) {
      throw new ConflictException('mail already in use');
    }

    try {
      const newUser = await this.usersService.create(email, password, username);

      const payload = { email: newUser.email, sub: newUser.id, username: newUser.username };

      return {
        access_token: this.jwtService.sign(payload),
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

    const payload = { email: user.email, sub: user.id, username: user.username };

    return {
      access_token: this.jwtService.sign(payload),
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
      },
    };
  }
}

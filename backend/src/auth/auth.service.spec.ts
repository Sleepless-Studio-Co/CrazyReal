import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { UsersService } from '../users/users.service';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { EmailVerificationService } from './email-verification.service';
import { GoogleAuthService } from './google-auth.service';
import * as bcrypt from 'bcrypt';

describe('AuthService', () => {
  let service: AuthService;

  const usersServiceMock = {
    findByEmail: jest.fn(),
    create: jest.fn(),
    findByEmailWithPassword: jest.fn(),
    findByGoogleId: jest.fn(),
    linkGoogleAccount: jest.fn(),
    createGoogleUser: jest.fn(),
  };

  const jwtServiceMock = {
    sign: jest.fn(),
  };

  const configServiceMock = {
    get: jest.fn(),
  };

  const prismaServiceMock = {
    refreshToken: {
      create: jest.fn(),
      findUnique: jest.fn(),
      updateMany: jest.fn(),
    },
  };

  const emailVerificationServiceMock = {
    createAndSend: jest.fn(),
    verify: jest.fn(),
    resendForUser: jest.fn(),
  };

  const googleAuthServiceMock = {
    verify: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    configServiceMock.get.mockImplementation((key: string) => {
      if (key === 'JWT_REFRESH_EXPIRATION') {
        return '30';
      }
      return undefined;
    });

    jwtServiceMock.sign.mockReturnValue('access-token');
    prismaServiceMock.refreshToken.create.mockResolvedValue({});
    emailVerificationServiceMock.createAndSend.mockResolvedValue(undefined);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        {
          provide: UsersService,
          useValue: usersServiceMock,
        },
        {
          provide: JwtService,
          useValue: jwtServiceMock,
        },
        {
          provide: ConfigService,
          useValue: configServiceMock,
        },
        {
          provide: PrismaService,
          useValue: prismaServiceMock,
        },
        {
          provide: EmailVerificationService,
          useValue: emailVerificationServiceMock,
        },
        {
          provide: GoogleAuthService,
          useValue: googleAuthServiceMock,
        },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  describe('register', () => {
    it('should register a user successfully', async () => {
      usersServiceMock.create.mockResolvedValue({
        id: 1,
        email: 'john@example.com',
        username: 'john',
      });

      const result = await service.register('john@example.com', 'StrongPassword123!', 'john');

      expect(result).toEqual({
        access_token: 'access-token',
        refresh_token: expect.any(String),
        user: {
          id: 1,
          email: 'john@example.com',
          username: 'john',
        },
      });
      expect(usersServiceMock.create).toHaveBeenCalledWith(
        'john@example.com',
        'StrongPassword123!',
        'john',
      );
      expect(jwtServiceMock.sign).toHaveBeenCalledWith({
        email: 'john@example.com',
        sub: 1,
        username: 'john',
      });
      expect(prismaServiceMock.refreshToken.create).toHaveBeenCalledWith({
        data: {
          token: expect.any(String),
          userId: 1,
          expiresAt: expect.any(Date),
        },
      });
    });

    it('should throw ConflictException when email is already used', async () => {
      // UsersService.create is the single source of truth for the P2002 → 409 mapping.
      usersServiceMock.create.mockRejectedValue(new ConflictException('mail already in use'));

      await expect(
        service.register('john@example.com', 'StrongPassword123!', 'john'),
      ).rejects.toThrow(ConflictException);

      expect(jwtServiceMock.sign).not.toHaveBeenCalled();
      expect(prismaServiceMock.refreshToken.create).not.toHaveBeenCalled();
    });
  });

  describe('login', () => {
    it('should login successfully with valid credentials', async () => {
      const hashedPassword = await bcrypt.hash('StrongPassword123!', 10);
      usersServiceMock.findByEmailWithPassword.mockResolvedValue({
        id: 2,
        email: 'jane@example.com',
        username: 'jane',
        password: hashedPassword,
      });

      const result = await service.login('jane@example.com', 'StrongPassword123!');

      expect(result).toEqual({
        access_token: 'access-token',
        refresh_token: expect.any(String),
        user: {
          id: 2,
          email: 'jane@example.com',
          username: 'jane',
        },
      });
      expect(jwtServiceMock.sign).toHaveBeenCalledWith({
        email: 'jane@example.com',
        sub: 2,
        username: 'jane',
      });
    });

    it('should throw UnauthorizedException with invalid credentials', async () => {
      const hashedPassword = await bcrypt.hash('StrongPassword123!', 10);
      usersServiceMock.findByEmailWithPassword.mockResolvedValue({
        id: 2,
        email: 'jane@example.com',
        username: 'jane',
        password: hashedPassword,
      });

      await expect(service.login('jane@example.com', 'wrong-password')).rejects.toThrow(
        UnauthorizedException,
      );
    });
  });

  describe('googleLogin', () => {
    const profile = {
      googleId: 'google-123',
      email: 'new@example.com',
      emailVerified: true,
      name: 'New User',
      picture: 'https://example.com/pic.png',
    };

    it('creates a new account when no account matches', async () => {
      googleAuthServiceMock.verify.mockResolvedValue(profile);
      usersServiceMock.findByGoogleId.mockResolvedValue(null);
      usersServiceMock.findByEmail.mockResolvedValue(null);
      usersServiceMock.createGoogleUser.mockResolvedValue({
        id: 5,
        email: 'new@example.com',
        username: 'newuser',
        avatarUrl: 'https://example.com/pic.png',
        avatarKey: null,
        emailVerified: true,
      });

      const result = await service.googleLogin('id-token');

      expect(result.access_token).toBe('access-token');
      expect(result.refresh_token).toEqual(expect.any(String));
      expect(result.user).toEqual({
        id: 5,
        email: 'new@example.com',
        username: 'newuser',
        avatarUrl: 'https://example.com/pic.png',
        avatarKey: null,
        emailVerified: true,
      });
      expect(usersServiceMock.createGoogleUser).toHaveBeenCalledWith({
        email: 'new@example.com',
        username: 'New User',
        googleId: 'google-123',
        avatarUrl: 'https://example.com/pic.png',
      });
    });

    it('links an existing email account to the Google identity', async () => {
      googleAuthServiceMock.verify.mockResolvedValue(profile);
      usersServiceMock.findByGoogleId.mockResolvedValue(null);
      usersServiceMock.findByEmail.mockResolvedValue({
        id: 7,
        email: 'new@example.com',
      });
      usersServiceMock.linkGoogleAccount.mockResolvedValue({
        id: 7,
        email: 'new@example.com',
        username: 'existing',
        avatarUrl: null,
        avatarKey: null,
        emailVerified: true,
      });

      const result = await service.googleLogin('id-token');

      expect(result.user.id).toBe(7);
      expect(usersServiceMock.linkGoogleAccount).toHaveBeenCalledWith(7, {
        googleId: 'google-123',
        avatarUrl: 'https://example.com/pic.png',
      });
      expect(usersServiceMock.createGoogleUser).not.toHaveBeenCalled();
    });

    it('signs in directly when the Google id is already linked', async () => {
      googleAuthServiceMock.verify.mockResolvedValue(profile);
      usersServiceMock.findByGoogleId.mockResolvedValue({
        id: 9,
        email: 'new@example.com',
        username: 'linked',
        avatarUrl: null,
        avatarKey: null,
        emailVerified: true,
      });

      const result = await service.googleLogin('id-token');

      expect(result.user.id).toBe(9);
      expect(usersServiceMock.findByEmail).not.toHaveBeenCalled();
    });

    it('rejects when the Google token is invalid', async () => {
      googleAuthServiceMock.verify.mockRejectedValue(
        new UnauthorizedException('Invalid Google token'),
      );

      await expect(service.googleLogin('bad-token')).rejects.toThrow(
        UnauthorizedException,
      );
      expect(jwtServiceMock.sign).not.toHaveBeenCalled();
    });

    it('rejects unverified Google emails', async () => {
      googleAuthServiceMock.verify.mockResolvedValue({
        ...profile,
        emailVerified: false,
      });

      await expect(service.googleLogin('id-token')).rejects.toThrow(
        UnauthorizedException,
      );
      expect(usersServiceMock.findByGoogleId).not.toHaveBeenCalled();
    });
  });
});

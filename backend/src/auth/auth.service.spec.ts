import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { UsersService } from '../users/users.service';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';

describe('AuthService', () => {
  let service: AuthService;

  const usersServiceMock = {
    findByEmail: jest.fn(),
    create: jest.fn(),
    findByEmailWithPassword: jest.fn(),
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
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  describe('register', () => {
    it('should register a user successfully', async () => {
      usersServiceMock.findByEmail.mockResolvedValue(null);
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
      expect(usersServiceMock.findByEmail).toHaveBeenCalledWith('john@example.com');
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
      usersServiceMock.findByEmail.mockResolvedValue({ id: 99, email: 'john@example.com' });

      await expect(
        service.register('john@example.com', 'StrongPassword123!', 'john'),
      ).rejects.toThrow(ConflictException);

      expect(usersServiceMock.create).not.toHaveBeenCalled();
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
});

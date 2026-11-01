import {
  ConflictException,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Test, TestingModule } from '@nestjs/testing';
import { UsersService } from './users.service';
import { PrismaService } from '../prisma/prisma.service';

describe('UsersService', () => {
  let service: UsersService;
  let prismaService: {
    user: {
      create: jest.Mock;
      findUnique: jest.Mock;
      findMany: jest.Mock;
      update: jest.Mock;
      delete: jest.Mock;
    };
    friendship: {
      findFirst: jest.Mock;
    };
  };

  beforeEach(async () => {
    prismaService = {
      user: {
        create: jest.fn(),
        findUnique: jest.fn(),
        findMany: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      friendship: {
        findFirst: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: PrismaService, useValue: prismaService },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('create', () => {
    it('hashes the password and creates the user with a safe select', async () => {
      prismaService.user.create.mockResolvedValue({ id: 1, email: 'a@b.com' });

      const result = await service.create('a@b.com', 'secret', 'alice');

      expect(prismaService.user.create).toHaveBeenCalledWith({
        data: {
          email: 'a@b.com',
          password: expect.any(String),
          username: 'alice',
        },
        select: expect.objectContaining({ id: true, emailVerified: true }),
      });
      // Password must be hashed, never stored in clear.
      const data = prismaService.user.create.mock.calls[0][0].data;
      expect(data.password).not.toBe('secret');
      expect(result).toEqual({ id: 1, email: 'a@b.com' });
    });
  });

  describe('findByEmail / findById / findAll', () => {
    it('delegates findByEmail to prisma with the right select', async () => {
      prismaService.user.findUnique.mockResolvedValue({ id: 1 });
      await service.findByEmail('a@b.com');
      expect(prismaService.user.findUnique).toHaveBeenCalledWith({
        where: { email: 'a@b.com' },
        select: expect.objectContaining({ id: true }),
      });
    });

    it('delegates findById and includes the role', async () => {
      prismaService.user.findUnique.mockResolvedValue({ id: 1, role: 'USER' });
      await service.findById(1);
      expect(prismaService.user.findUnique).toHaveBeenCalledWith({
        where: { id: 1 },
        select: expect.objectContaining({ role: true }),
      });
    });

    it('delegates findAll to prisma.findMany', async () => {
      prismaService.user.findMany.mockResolvedValue([]);
      await service.findAll();
      expect(prismaService.user.findMany).toHaveBeenCalled();
    });
  });

  describe('searchByUsername', () => {
    it('searches case-insensitively and excludes the requester', async () => {
      prismaService.user.findMany.mockResolvedValue([]);
      await service.searchByUsername('ali', 5);
      expect(prismaService.user.findMany).toHaveBeenCalledWith({
        where: {
          username: { contains: 'ali', mode: 'insensitive' },
          NOT: { id: 5 },
        },
        select: expect.objectContaining({ username: true, isPrivate: true }),
        orderBy: { username: 'asc' },
        take: 20,
      });
    });
  });

  describe('updateProfile / updateAvatar / updatePrivacy', () => {
    it('delegates updateProfile with the given partial updates', async () => {
      prismaService.user.update.mockResolvedValue({ id: 1 });
      await service.updateProfile(1, { username: 'bob' });
      expect(prismaService.user.update).toHaveBeenCalledWith({
        where: { id: 1 },
        data: { username: 'bob' },
        select: expect.objectContaining({ id: true }),
      });
    });

    it('delegates updateAvatar', async () => {
      prismaService.user.update.mockResolvedValue({ id: 1 });
      await service.updateAvatar(1, {
        avatarUrl: '/uploads/x.png',
        avatarKey: null,
      });
      expect(prismaService.user.update).toHaveBeenCalledWith({
        where: { id: 1 },
        data: { avatarUrl: '/uploads/x.png', avatarKey: null },
        select: expect.objectContaining({ id: true }),
      });
    });

    it('delegates updatePrivacy', async () => {
      prismaService.user.update.mockResolvedValue({ id: 1, isPrivate: true });
      await service.updatePrivacy(1, true);
      expect(prismaService.user.update).toHaveBeenCalledWith({
        where: { id: 1 },
        data: { isPrivate: true },
        select: expect.objectContaining({ id: true }),
      });
    });
  });

  describe('deleteAccount', () => {
    it('deletes the user', async () => {
      prismaService.user.delete.mockResolvedValue({ id: 1 });
      await service.deleteAccount(1);
      expect(prismaService.user.delete).toHaveBeenCalledWith({
        where: { id: 1 },
      });
    });
  });

  describe('findPublicProfile', () => {
    it('throws NotFoundException when the target does not exist', async () => {
      prismaService.user.findUnique.mockResolvedValue(null);
      await expect(service.findPublicProfile(99, 1)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('returns the own profile with isSelf/isFriend flags', async () => {
      prismaService.user.findUnique.mockResolvedValue({
        id: 1,
        username: 'me',
        isPrivate: true,
      });
      await expect(service.findPublicProfile(1, 1)).resolves.toEqual(
        expect.objectContaining({ id: 1, isSelf: true, isFriend: true }),
      );
    });

    it('returns a public profile without needing friendship', async () => {
      prismaService.user.findUnique.mockResolvedValue({
        id: 2,
        username: 'bob',
        isPrivate: false,
      });
      await expect(service.findPublicProfile(2, 1)).resolves.toEqual(
        expect.objectContaining({ id: 2, isSelf: false, isFriend: false }),
      );
    });

    it('returns the full profile for an accepted friend of a private user', async () => {
      prismaService.user.findUnique.mockResolvedValue({
        id: 2,
        username: 'bob',
        isPrivate: true,
        avatarUrl: null,
        avatarKey: null,
      });
      prismaService.friendship.findFirst.mockResolvedValue({ id: 9 });

      await expect(service.findPublicProfile(2, 1)).resolves.toEqual(
        expect.objectContaining({ id: 2, isFriend: true, isSelf: false }),
      );
    });

    it('returns a minimal locked profile for a non-friend private user', async () => {
      prismaService.user.findUnique.mockResolvedValue({
        id: 2,
        username: 'bob',
        isPrivate: true,
        avatarUrl: '/uploads/x.png',
        avatarKey: null,
      });
      prismaService.friendship.findFirst.mockResolvedValue(null);

      await expect(service.findPublicProfile(2, 1)).resolves.toEqual({
        id: 2,
        username: 'bob',
        avatarUrl: '/uploads/x.png',
        avatarKey: null,
        isPrivate: true,
        isFriend: false,
        isSelf: false,
      });
    });
  });

  describe('handlePrismaError', () => {
    const knownRequestError = (code: string, target?: unknown) =>
      new Prisma.PrismaClientKnownRequestError('boom', {
        code,
        clientVersion: 'test',
        meta: { target },
      });

    it('maps a P2002 on email to a ConflictException', async () => {
      prismaService.user.create.mockRejectedValue(
        knownRequestError('P2002', ['email']),
      );
      await expect(service.create('a@b.com', 'x', 'y')).rejects.toBeInstanceOf(
        ConflictException,
      );
    });

    it('maps a P2002 on username to a ConflictException', async () => {
      prismaService.user.create.mockRejectedValue(
        knownRequestError('P2002', ['username']),
      );
      await expect(service.create('a@b.com', 'x', 'y')).rejects.toThrow(
        'username already in use',
      );
    });

    it('maps any other P2002 to a generic ConflictException', async () => {
      prismaService.user.create.mockRejectedValue(
        knownRequestError('P2002', ['other']),
      );
      await expect(service.create('a@b.com', 'x', 'y')).rejects.toThrow(
        'unique constraint violation',
      );
    });

    it('maps a P2025 to NotFoundException', async () => {
      prismaService.user.update.mockRejectedValue(knownRequestError('P2025'));
      await expect(service.updateProfile(1, {})).rejects.toThrow(
        'user not found',
      );
    });

    it('maps unknown errors to InternalServerErrorException', async () => {
      prismaService.user.create.mockRejectedValue(new Error('db down'));
      await expect(service.create('a@b.com', 'x', 'y')).rejects.toBeInstanceOf(
        InternalServerErrorException,
      );
    });
  });
});

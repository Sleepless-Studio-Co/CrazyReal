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
      count: jest.Mock;
    };
    post: {
      findMany: jest.Mock;
    };
  };

  const bob = {
    id: 2,
    username: 'bob',
    avatarUrl: '/uploads/bob.png',
    avatarKey: null,
    isPrivate: false,
    createdAt: new Date('2026-01-01'),
  };
  const rawPost = {
    id: 11,
    photoUrl: '/uploads/p.jpg',
    _count: { upVotes: 3 },
    upVotes: [{ id: 1 }],
  };

  /// Le service appelle `friendship.count` deux fois : lien d'amitié
  /// viewer↔cible (sauf pour soi-même), puis nombre d'amis de la cible.
  function mockFriendship({
    isFriend,
    friendCount,
  }: {
    isFriend: boolean;
    friendCount: number;
  }) {
    prismaService.friendship.count.mockImplementation(({ where }) =>
      Promise.resolve(
        where.OR.length === 2 &&
          'friendId' in where.OR[0] &&
          'userId' in where.OR[0]
          ? Number(isFriend)
          : friendCount,
      ),
    );
  }

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
        count: jest.fn().mockResolvedValue(0),
      },
      post: {
        findMany: jest.fn().mockResolvedValue([rawPost]),
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
    it('searches case-insensitively, excludes the requester and caps results', async () => {
      prismaService.user.findMany.mockResolvedValue([]);

      await service.searchByUsername('Bo', 5);

      expect(prismaService.user.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            username: { contains: 'Bo', mode: 'insensitive' },
            NOT: { id: 5 },
          },
          orderBy: { username: 'asc' },
          take: 20,
        }),
      );
    });

    it('exposes the privacy flag but not the email', async () => {
      prismaService.user.findMany.mockResolvedValue([]);

      await service.searchByUsername('bo', 1);

      const { select } = prismaService.user.findMany.mock.calls[0][0];
      expect(select).toMatchObject({
        id: true,
        username: true,
        isPrivate: true,
      });
      expect(select).not.toHaveProperty('email');
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

    it.each([true, false])(
      'stores isPrivate=%s for the given user',
      async (isPrivate) => {
        prismaService.user.update.mockResolvedValue({ id: 1, isPrivate });

        await expect(service.updatePrivacy(1, isPrivate)).resolves.toEqual({
          id: 1,
          isPrivate,
        });
        expect(prismaService.user.update).toHaveBeenCalledWith(
          expect.objectContaining({ where: { id: 1 }, data: { isPrivate } }),
        );
      },
    );
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
    it('throws NotFoundException (not a 500) for an unknown user', async () => {
      prismaService.user.findUnique.mockResolvedValue(null);

      await expect(service.findPublicProfile(99, 1)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('shows a public profile and its posts to anyone', async () => {
      prismaService.user.findUnique.mockResolvedValue(bob);
      mockFriendship({ isFriend: false, friendCount: 4 });

      const profile = await service.findPublicProfile(2, 1);

      expect(profile).toMatchObject({
        id: 2,
        username: 'bob',
        isPrivate: false,
        isFriend: false,
        isSelf: false,
        friendCount: 4,
      });
      expect(profile?.posts).toHaveLength(1);
    });

    it('locks a private profile for a non-friend', async () => {
      prismaService.user.findUnique.mockResolvedValue({
        ...bob,
        isPrivate: true,
      });
      mockFriendship({ isFriend: false, friendCount: 4 });

      const profile = await service.findPublicProfile(2, 1);

      expect(profile).toEqual({
        id: 2,
        username: 'bob',
        avatarUrl: '/uploads/bob.png',
        avatarKey: null,
        isPrivate: true,
        isFriend: false,
        isSelf: false,
        friendCount: 4,
        posts: [],
      });
      expect(prismaService.post.findMany).not.toHaveBeenCalled();
    });

    it('does not leak createdAt on a locked profile', async () => {
      prismaService.user.findUnique.mockResolvedValue({
        ...bob,
        isPrivate: true,
      });
      mockFriendship({ isFriend: false, friendCount: 0 });

      const profile = await service.findPublicProfile(2, 1);

      expect(profile).not.toHaveProperty('createdAt');
    });

    it('opens a private profile to an accepted friend', async () => {
      prismaService.user.findUnique.mockResolvedValue({
        ...bob,
        isPrivate: true,
      });
      mockFriendship({ isFriend: true, friendCount: 4 });

      const profile = await service.findPublicProfile(2, 1);

      expect(profile).toMatchObject({
        isPrivate: true,
        isFriend: true,
        isSelf: false,
      });
      expect(profile?.posts).toHaveLength(1);
    });

    it('always opens your own private profile', async () => {
      prismaService.user.findUnique.mockResolvedValue({
        ...bob,
        isPrivate: true,
      });
      mockFriendship({ isFriend: false, friendCount: 0 });

      const profile = await service.findPublicProfile(2, 2);

      expect(profile).toMatchObject({ isSelf: true, isFriend: true });
      expect(profile?.posts).toHaveLength(1);
    });

    it('only counts ACCEPTED friendships, in both directions', async () => {
      prismaService.user.findUnique.mockResolvedValue(bob);
      mockFriendship({ isFriend: false, friendCount: 0 });

      await service.findPublicProfile(2, 1);

      expect(prismaService.friendship.count).toHaveBeenCalledWith({
        where: { status: 'ACCEPTED', OR: [{ userId: 2 }, { friendId: 2 }] },
      });
      expect(prismaService.friendship.count).toHaveBeenCalledWith({
        where: {
          status: 'ACCEPTED',
          OR: [
            { userId: 1, friendId: 2 },
            { userId: 2, friendId: 1 },
          ],
        },
      });
    });

    it('excludes group-challenge posts, newest first', async () => {
      prismaService.user.findUnique.mockResolvedValue(bob);
      mockFriendship({ isFriend: true, friendCount: 1 });

      await service.findPublicProfile(2, 1);

      const query = prismaService.post.findMany.mock.calls[0][0];
      expect(query.where).toEqual({
        userId: 2,
        challenge: { conversationId: null },
      });
      expect(query.orderBy).toEqual({ createdAt: 'desc' });
    });

    it('computes upvotes from the viewer point of view', async () => {
      prismaService.user.findUnique.mockResolvedValue(bob);
      mockFriendship({ isFriend: true, friendCount: 1 });

      const profile = await service.findPublicProfile(2, 1);

      const query = prismaService.post.findMany.mock.calls[0][0];
      expect(query.include.upVotes.where).toEqual({ userId: 1 });
      expect(profile?.posts[0]).toEqual({
        id: 11,
        photoUrl: '/uploads/p.jpg',
        upvoteCount: 3,
        hasUpvoted: true,
        reactions: [],
      });
    });

    it('never selects the email or password of the target', async () => {
      prismaService.user.findUnique.mockResolvedValue(bob);
      mockFriendship({ isFriend: false, friendCount: 0 });

      await service.findPublicProfile(2, 1);

      const { select } = prismaService.user.findUnique.mock.calls[0][0];
      expect(select).not.toHaveProperty('email');
      expect(select).not.toHaveProperty('password');
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
      prismaService.user.update.mockRejectedValue(
        knownRequestError('P2025'),
      );
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

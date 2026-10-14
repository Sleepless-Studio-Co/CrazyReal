import { NotFoundException } from '@nestjs/common';
import { UsersService } from './users.service';
import { PrismaService } from '../prisma/prisma.service';

describe('UsersService', () => {
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
  let prisma: {
    user: { findUnique: jest.Mock; findMany: jest.Mock; update: jest.Mock };
    friendship: { count: jest.Mock };
    post: { findMany: jest.Mock };
  };
  let service: UsersService;

  /// Le service appelle `friendship.count` deux fois : lien d'amitié
  /// viewer↔cible (sauf pour soi-même), puis nombre d'amis de la cible.
  function mockFriendship({ isFriend, friendCount }: { isFriend: boolean; friendCount: number }) {
    prisma.friendship.count.mockImplementation(({ where }) =>
      Promise.resolve(
        where.OR.length === 2 && 'friendId' in where.OR[0] && 'userId' in where.OR[0]
          ? Number(isFriend)
          : friendCount,
      ),
    );
  }

  beforeEach(() => {
    prisma = {
      user: { findUnique: jest.fn(), findMany: jest.fn(), update: jest.fn() },
      friendship: { count: jest.fn() },
      post: { findMany: jest.fn().mockResolvedValue([rawPost]) },
    };
    service = new UsersService(prisma as unknown as PrismaService);
  });

  describe('findPublicProfile', () => {
    it('should throw NotFoundException (not a 500) for an unknown user', async () => {
      prisma.user.findUnique.mockResolvedValue(null);

      await expect(service.findPublicProfile(99, 1)).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should show a public profile and its posts to anyone', async () => {
      prisma.user.findUnique.mockResolvedValue(bob);
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

    it('should lock a private profile for a non-friend', async () => {
      prisma.user.findUnique.mockResolvedValue({ ...bob, isPrivate: true });
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
      expect(prisma.post.findMany).not.toHaveBeenCalled();
    });

    it('should not leak createdAt on a locked profile', async () => {
      prisma.user.findUnique.mockResolvedValue({ ...bob, isPrivate: true });
      mockFriendship({ isFriend: false, friendCount: 0 });

      const profile = await service.findPublicProfile(2, 1);

      expect(profile).not.toHaveProperty('createdAt');
    });

    it('should open a private profile to an accepted friend', async () => {
      prisma.user.findUnique.mockResolvedValue({ ...bob, isPrivate: true });
      mockFriendship({ isFriend: true, friendCount: 4 });

      const profile = await service.findPublicProfile(2, 1);

      expect(profile).toMatchObject({ isPrivate: true, isFriend: true, isSelf: false });
      expect(profile?.posts).toHaveLength(1);
    });

    it('should always open your own private profile', async () => {
      prisma.user.findUnique.mockResolvedValue({ ...bob, isPrivate: true });
      mockFriendship({ isFriend: false, friendCount: 0 });

      const profile = await service.findPublicProfile(2, 2);

      expect(profile).toMatchObject({ isSelf: true, isFriend: true });
      expect(profile?.posts).toHaveLength(1);
    });

    it('should only count ACCEPTED friendships, in both directions', async () => {
      prisma.user.findUnique.mockResolvedValue(bob);
      mockFriendship({ isFriend: false, friendCount: 0 });

      await service.findPublicProfile(2, 1);

      expect(prisma.friendship.count).toHaveBeenCalledWith({
        where: { status: 'ACCEPTED', OR: [{ userId: 2 }, { friendId: 2 }] },
      });
      expect(prisma.friendship.count).toHaveBeenCalledWith({
        where: {
          status: 'ACCEPTED',
          OR: [
            { userId: 1, friendId: 2 },
            { userId: 2, friendId: 1 },
          ],
        },
      });
    });

    it('should exclude group-challenge posts, newest first', async () => {
      prisma.user.findUnique.mockResolvedValue(bob);
      mockFriendship({ isFriend: true, friendCount: 1 });

      await service.findPublicProfile(2, 1);

      const query = prisma.post.findMany.mock.calls[0][0];
      expect(query.where).toEqual({ userId: 2, challenge: { conversationId: null } });
      expect(query.orderBy).toEqual({ createdAt: 'desc' });
    });

    it('should compute upvotes from the viewer point of view', async () => {
      prisma.user.findUnique.mockResolvedValue(bob);
      mockFriendship({ isFriend: true, friendCount: 1 });

      const profile = await service.findPublicProfile(2, 1);

      const query = prisma.post.findMany.mock.calls[0][0];
      expect(query.include.upVotes.where).toEqual({ userId: 1 });
      expect(profile?.posts[0]).toEqual({
        id: 11,
        photoUrl: '/uploads/p.jpg',
        upvoteCount: 3,
        hasUpvoted: true,
      });
    });

    it('should never select the email or password of the target', async () => {
      prisma.user.findUnique.mockResolvedValue(bob);
      mockFriendship({ isFriend: false, friendCount: 0 });

      await service.findPublicProfile(2, 1);

      const { select } = prisma.user.findUnique.mock.calls[0][0];
      expect(select).not.toHaveProperty('email');
      expect(select).not.toHaveProperty('password');
    });
  });

  describe('searchByUsername', () => {
    it('should search case-insensitively, exclude the requester and cap results', async () => {
      prisma.user.findMany.mockResolvedValue([]);

      await service.searchByUsername('Bo', 1);

      expect(prisma.user.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            username: { contains: 'Bo', mode: 'insensitive' },
            NOT: { id: 1 },
          },
          take: 20,
        }),
      );
    });

    it('should expose the privacy flag but not the email', async () => {
      prisma.user.findMany.mockResolvedValue([]);

      await service.searchByUsername('bo', 1);

      const { select } = prisma.user.findMany.mock.calls[0][0];
      expect(select).toMatchObject({ id: true, username: true, isPrivate: true });
      expect(select).not.toHaveProperty('email');
    });
  });

  describe('updatePrivacy', () => {
    it.each([true, false])('should store isPrivate=%s for the given user', async (isPrivate) => {
      prisma.user.update.mockResolvedValue({ id: 1, isPrivate });

      await expect(service.updatePrivacy(1, isPrivate)).resolves.toEqual({ id: 1, isPrivate });
      expect(prisma.user.update).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id: 1 }, data: { isPrivate } }),
      );
    });
  });
});

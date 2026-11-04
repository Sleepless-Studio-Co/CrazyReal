import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { UsersService } from './users.service';

describe('UsersService public profile', () => {
  const streak = {
    current: 4,
    best: 9,
    status: 'active',
    hasPostedInCurrentEdition: true,
    currentEdition: null,
    participatedEditions: 7,
  };

  let prisma: {
    user: { findUnique: jest.Mock<any> };
    friendship: { findFirst: jest.Mock<any> };
    post: { count: jest.Mock<any>; findMany: jest.Mock<any> };
  };
  let streakService: { getStreakForUser: jest.Mock<any> };
  let service: UsersService;

  const target = {
    id: 2,
    username: 'target',
    avatarUrl: null,
    avatarKey: null,
    isPrivate: false,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
  };

  beforeEach(() => {
    prisma = {
      user: { findUnique: jest.fn() },
      friendship: { findFirst: jest.fn() },
      post: { count: jest.fn(), findMany: jest.fn() },
    };
    streakService = { getStreakForUser: jest.fn() };
    service = new UsersService(prisma as any, streakService as any);
  });

  it('includes the streak and stats on a public profile', async () => {
    prisma.user.findUnique.mockResolvedValue(target);
    prisma.friendship.findFirst.mockResolvedValue(null);
    streakService.getStreakForUser.mockResolvedValue(streak);
    prisma.post.count.mockResolvedValue(12);

    const profile = await service.findPublicProfile(2, 1);

    expect(profile).toMatchObject({
      id: 2,
      canViewContent: true,
      isFriend: false,
      isSelf: false,
      streak,
      stats: { postsCount: 12, challengesCount: 7 },
    });
  });

  it('hides the streak from a non-friend on a private profile', async () => {
    prisma.user.findUnique.mockResolvedValue({ ...target, isPrivate: true });
    prisma.friendship.findFirst.mockResolvedValue(null);

    const profile = await service.findPublicProfile(2, 1);

    expect(profile).toEqual({
      id: 2,
      username: 'target',
      avatarUrl: null,
      avatarKey: null,
      isPrivate: true,
      isFriend: false,
      isSelf: false,
      canViewContent: false,
    });
    expect(streakService.getStreakForUser).not.toHaveBeenCalled();
  });

  it('shows the streak to an accepted friend of a private profile', async () => {
    prisma.user.findUnique.mockResolvedValue({ ...target, isPrivate: true });
    prisma.friendship.findFirst.mockResolvedValue({ id: 1 });
    streakService.getStreakForUser.mockResolvedValue(streak);
    prisma.post.count.mockResolvedValue(3);

    const profile = await service.findPublicProfile(2, 1);

    expect(profile).toMatchObject({
      canViewContent: true,
      isFriend: true,
      streak,
    });
  });

  it('always shows the streak on one’s own profile', async () => {
    prisma.user.findUnique.mockResolvedValue({ ...target, isPrivate: true });
    streakService.getStreakForUser.mockResolvedValue(streak);
    prisma.post.count.mockResolvedValue(3);

    const profile = await service.findPublicProfile(2, 2);

    expect(profile).toMatchObject({
      canViewContent: true,
      isSelf: true,
      isFriend: true,
      streak,
    });
    expect(prisma.friendship.findFirst).not.toHaveBeenCalled();
  });

  it('throws NotFound when the profile does not exist', async () => {
    prisma.user.findUnique.mockResolvedValue(null);

    await expect(service.findPublicProfile(404, 1)).rejects.toThrow(
      NotFoundException,
    );
  });

  it('refuses to list posts of a private non-friend', async () => {
    prisma.user.findUnique.mockResolvedValue({ ...target, isPrivate: true });
    prisma.friendship.findFirst.mockResolvedValue(null);

    await expect(service.findPublicPosts(2, 1)).rejects.toThrow(
      ForbiddenException,
    );
  });

  it('only lists posts made on global challenges', async () => {
    prisma.user.findUnique.mockResolvedValue(target);
    prisma.friendship.findFirst.mockResolvedValue(null);
    prisma.post.findMany.mockResolvedValue([]);

    await service.findPublicPosts(2, 1, 30);

    expect(prisma.post.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          userId: 2,
          challenge: { is: { conversationId: null } },
        }),
      }),
    );
  });
});

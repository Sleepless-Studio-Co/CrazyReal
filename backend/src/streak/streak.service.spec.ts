import { ChallengeType } from '@prisma/client';
import { StreakService } from './streak.service';

describe('StreakService', () => {
  const now = new Date('2026-01-10T12:00:00.000Z');
  const day = (offset: number) => {
    const date = new Date(now);
    date.setUTCDate(date.getUTCDate() + offset);
    return date;
  };

  let prisma: {
    challenge: { findMany: jest.Mock<any> };
    post: { findMany: jest.Mock<any> };
  };
  let service: StreakService;

  beforeEach(() => {
    prisma = {
      challenge: { findMany: jest.fn() },
      post: { findMany: jest.fn() },
    };
    service = new StreakService(prisma as any);
  });

  it('maps posts to grouped editions and only queries global challenges', async () => {
    prisma.challenge.findMany.mockResolvedValue([
      {
        id: 1,
        title: 'Weekly',
        date: day(-2),
        endsAt: day(2),
        durationHours: null,
        type: ChallengeType.WEEKLY_A,
        isActive: true,
      },
      {
        id: 2,
        title: 'Special',
        date: day(-2),
        endsAt: day(2),
        durationHours: null,
        type: ChallengeType.SPECIAL,
        isActive: true,
      },
      {
        id: 3,
        title: 'Next',
        date: day(-1),
        endsAt: day(3),
        durationHours: null,
        type: ChallengeType.WEEKLY_A,
        isActive: true,
      },
    ]);
    prisma.post.findMany.mockResolvedValue([
      { challengeId: 2 },
      { challengeId: 3 },
    ]);

    const summary = await service.getStreakForUser(42, now);

    expect(summary.current).toBe(2);
    expect(summary.participatedEditions).toBe(2);
    expect(prisma.challenge.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          conversationId: null,
          isActive: true,
        }),
      }),
    );
    expect(prisma.post.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          userId: 42,
          challenge: {
            is: {
              conversationId: null,
              isActive: true,
            },
          },
        }),
        distinct: ['challengeId'],
      }),
    );
  });

  it('does not count a post made in a challenge that is not in the edition list', async () => {
    prisma.challenge.findMany.mockResolvedValue([
      {
        id: 1,
        title: 'Weekly',
        date: day(-1),
        endsAt: day(2),
        durationHours: null,
        type: ChallengeType.WEEKLY_A,
        isActive: true,
      },
    ]);
    prisma.post.findMany.mockResolvedValue([{ challengeId: 999 }]);

    const summary = await service.getStreakForUser(42, now);

    expect(summary.current).toBe(0);
    expect(summary.participatedEditions).toBe(0);
  });
});

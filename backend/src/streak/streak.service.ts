import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  ChallengeForStreak,
  computeStreak,
  groupChallengesIntoEditions,
  StreakSummary,
} from './streak.utils';

@Injectable()
export class StreakService {
  constructor(private readonly prisma: PrismaService) {}

  async getStreakForUser(
    userId: number,
    now: Date = new Date(),
  ): Promise<StreakSummary> {
    const [challenges, userPosts] = await Promise.all([
      this.prisma.challenge.findMany({
        where: {
          conversationId: null,
          isActive: true,
          date: { lte: now },
        },
        select: {
          id: true,
          title: true,
          date: true,
          endsAt: true,
          durationHours: true,
          type: true,
          isActive: true,
        },
      }),
      this.prisma.post.findMany({
        where: {
          userId,
          challenge: {
            is: {
              conversationId: null,
              isActive: true,
            },
          },
        },
        select: { challengeId: true },
        distinct: ['challengeId'],
      }),
    ]);

    const editions = groupChallengesIntoEditions(
      challenges as ChallengeForStreak[],
      now,
    );

    const editionKeysByChallengeId = new Map(
      challenges.map((challenge) => [challenge.id, challenge.date.getTime()]),
    );
    const participatedEditionKeys = new Set(
      userPosts
        .map((post) => editionKeysByChallengeId.get(post.challengeId))
        .filter((key): key is number => key !== undefined),
    );

    return computeStreak(
      editions.map((edition) => ({
        ...edition,
        participated: participatedEditionKeys.has(edition.key),
      })),
      now,
    );
  }
}

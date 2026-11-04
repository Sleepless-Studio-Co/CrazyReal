import { ChallengeType } from '@prisma/client';
import {
  ChallengeForStreak,
  StreakEditionState,
  computeStreak,
  groupChallengesIntoEditions,
  resolveChallengeEnd,
} from './streak.utils';

const now = new Date('2026-01-10T12:00:00.000Z');

function day(offset: number, hour = 0): Date {
  const date = new Date(now);
  date.setUTCDate(date.getUTCDate() + offset);
  date.setUTCHours(hour, 0, 0, 0);
  return date;
}

function edition(
  id: number,
  startsAt: Date,
  endsAt: Date,
  participated: boolean,
): StreakEditionState {
  return {
    key: startsAt.getTime(),
    id,
    title: `Edition ${id}`,
    startsAt,
    endsAt,
    participated,
  };
}

function challenge(
  id: number,
  startsAt: Date,
  overrides: Partial<ChallengeForStreak> = {},
): ChallengeForStreak {
  return {
    id,
    title: `Challenge ${id}`,
    date: startsAt,
    endsAt: null,
    durationHours: null,
    type: ChallengeType.WEEKLY_A,
    isActive: true,
    ...overrides,
  };
}

describe('resolveChallengeEnd', () => {
  it('uses the explicit end date when present', () => {
    const end = day(2);
    expect(resolveChallengeEnd(challenge(1, day(0), { endsAt: end }))).toEqual(
      end,
    );
  });

  it('defaults special challenges to 24 hours and weeklies to 84 hours', () => {
    const start = day(0);
    expect(
      resolveChallengeEnd(
        challenge(1, start, { type: ChallengeType.SPECIAL }),
      ).getTime(),
    ).toBe(start.getTime() + 24 * 60 * 60 * 1000);
    expect(resolveChallengeEnd(challenge(2, start)).getTime()).toBe(
      start.getTime() + 84 * 60 * 60 * 1000,
    );
  });
});

describe('groupChallengesIntoEditions', () => {
  it('groups challenges that start at the exact same instant', () => {
    const start = day(-1);
    const editions = groupChallengesIntoEditions(
      [
        challenge(1, start, {
          title: 'Weekly',
          type: ChallengeType.WEEKLY_A,
        }),
        challenge(2, start, {
          title: 'Special',
          type: ChallengeType.SPECIAL,
        }),
      ],
      now,
    );

    expect(editions).toHaveLength(1);
    // SPECIAL wins the title, but the edition lasts until the longest window.
    expect(editions[0].title).toBe('Special');
    expect(editions[0].endsAt.getTime()).toBe(
      start.getTime() + 84 * 60 * 60 * 1000,
    );
  });

  it('ignores inactive and future challenges', () => {
    const editions = groupChallengesIntoEditions(
      [challenge(1, day(-1), { isActive: false }), challenge(2, day(1))],
      now,
    );

    expect(editions).toEqual([]);
  });
});

describe('computeStreak', () => {
  it('returns an empty summary when the user has no history', () => {
    const summary = computeStreak([], now);

    expect(summary.current).toBe(0);
    expect(summary.best).toBe(0);
    expect(summary.status).toBe('none');
    expect(summary.currentEdition).toBeNull();
  });

  it('counts consecutive participated editions', () => {
    const summary = computeStreak(
      [
        edition(1, day(-3), day(-1), true),
        edition(2, day(-2), day(0), true),
        edition(3, day(-1), day(1), true),
      ],
      now,
    );

    expect(summary.current).toBe(3);
    expect(summary.best).toBe(3);
    expect(summary.status).toBe('active');
    expect(summary.participatedEditions).toBe(3);
  });

  it('keeps the streak during the grace period of the latest edition', () => {
    const summary = computeStreak(
      [edition(1, day(-2), day(0), true), edition(2, day(-1), day(1), false)],
      now,
    );

    expect(summary.current).toBe(1);
    expect(summary.status).toBe('at_risk');
    expect(summary.hasPostedInCurrentEdition).toBe(false);
    expect(summary.currentEdition?.id).toBe(2);
  });

  it('resets once a missed edition has ended', () => {
    const summary = computeStreak(
      [edition(1, day(-4), day(-2), true), edition(2, day(-3), day(-1), false)],
      now,
    );

    expect(summary.current).toBe(0);
    expect(summary.best).toBe(1);
    expect(summary.status).toBe('none');
  });

  it('does not let a later post bridge a skipped open edition', () => {
    const summary = computeStreak(
      [
        edition(1, day(-3), day(-1), true),
        edition(2, day(-2), day(2), false),
        edition(3, day(-1), day(3), true),
      ],
      now,
    );

    expect(summary.current).toBe(1);
    expect(summary.best).toBe(1);
  });

  it('starts at one after a reset when the user posts again', () => {
    const summary = computeStreak(
      [
        edition(1, day(-5), day(-3), true),
        edition(2, day(-4), day(-2), false),
        edition(3, day(-2), day(1), true),
      ],
      now,
    );

    expect(summary.current).toBe(1);
    expect(summary.best).toBe(1);
  });

  it('keeps the best streak from history', () => {
    const summary = computeStreak(
      [
        edition(1, day(-6), day(-4), true),
        edition(2, day(-5), day(-3), true),
        edition(3, day(-4), day(-2), true),
        edition(4, day(-3), day(-1), false),
        edition(5, day(-2), day(1), true),
      ],
      now,
    );

    expect(summary.current).toBe(1);
    expect(summary.best).toBe(3);
  });
});

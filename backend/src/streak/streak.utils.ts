import { ChallengeType } from '@prisma/client';

/**
 * A global challenge is considered part of the same "edition" as every other
 * global challenge that starts at the exact same instant. This matches the way
 * the seed/admin can publish WEEKLY_A, WEEKLY_B and SPECIAL prompts together:
 * answering any one of them is enough for the edition to count.
 */
export interface ChallengeForStreak {
  id: number;
  title: string;
  date: Date;
  endsAt: Date | null;
  durationHours: number | null;
  type: ChallengeType;
  isActive: boolean;
}

export interface StreakEdition {
  /** Stable key: the edition start instant. */
  key: number;
  id: number;
  title: string;
  startsAt: Date;
  endsAt: Date;
}

export interface StreakEditionState extends StreakEdition {
  participated: boolean;
}

export type StreakStatus = 'active' | 'at_risk' | 'none';

export interface StreakCurrentEdition {
  id: number;
  title: string;
  startsAt: Date;
  endsAt: Date;
  participated: boolean;
}

export interface StreakSummary {
  current: number;
  best: number;
  status: StreakStatus;
  hasPostedInCurrentEdition: boolean;
  currentEdition: StreakCurrentEdition | null;
  /** Number of distinct global editions the user has posted in. */
  participatedEditions: number;
}

const SPECIAL_DURATION_HOURS = 24;
const DEFAULT_GLOBAL_DURATION_HOURS = 84;

const TYPE_PRIORITY: Record<ChallengeType, number> = {
  SPECIAL: 0,
  WEEKLY_A: 1,
  WEEKLY_B: 2,
};

export function resolveChallengeEnd(
  challenge: Pick<
    ChallengeForStreak,
    'date' | 'endsAt' | 'durationHours' | 'type'
  >,
): Date {
  if (challenge.endsAt) {
    return challenge.endsAt;
  }

  const durationHours =
    challenge.durationHours ??
    (challenge.type === ChallengeType.SPECIAL
      ? SPECIAL_DURATION_HOURS
      : DEFAULT_GLOBAL_DURATION_HOURS);

  return new Date(challenge.date.getTime() + durationHours * 60 * 60 * 1000);
}

/**
 * Groups active global challenges into editions. Challenges that start in the
 * future or that have been deactivated are ignored: they must neither validate
 * nor break a streak.
 */
export function groupChallengesIntoEditions(
  challenges: ChallengeForStreak[],
  now: Date,
): StreakEdition[] {
  const groups = new Map<number, ChallengeForStreak[]>();

  for (const challenge of challenges) {
    if (!challenge.isActive || challenge.date.getTime() > now.getTime()) {
      continue;
    }

    const key = challenge.date.getTime();
    const group = groups.get(key);
    if (group) {
      group.push(challenge);
    } else {
      groups.set(key, [challenge]);
    }
  }

  return [...groups.entries()]
    .map(([key, group]) => {
      const representative = [...group].sort((a, b) => {
        const byType = TYPE_PRIORITY[a.type] - TYPE_PRIORITY[b.type];
        return byType !== 0 ? byType : a.id - b.id;
      })[0];

      const endsAt = group.reduce(
        (latest, challenge) =>
          resolveChallengeEnd(challenge).getTime() > latest.getTime()
            ? resolveChallengeEnd(challenge)
            : latest,
        resolveChallengeEnd(group[0]),
      );

      return {
        key,
        id: representative.id,
        title: representative.title,
        startsAt: new Date(key),
        endsAt,
      } satisfies StreakEdition;
    })
    .sort((a, b) => a.startsAt.getTime() - b.startsAt.getTime());
}

/**
 * Computes the current and best streaks.
 *
 * Rules:
 * - One participation per edition, even if the user posted several times.
 * - An open edition the user has not answered yet does not break the streak
 *   (grace period), but a closed missed edition does.
 * - A missed open edition that sits *before* a later participation still breaks
 *   the run: a user cannot bridge a challenge they skipped.
 * - If no global challenge exists for weeks, the streak does not decay. Only a
 *   missed edition can reset it.
 */
export function computeStreak(
  editions: StreakEditionState[],
  now: Date,
): StreakSummary {
  const sorted = [...editions].sort(
    (a, b) => a.startsAt.getTime() - b.startsAt.getTime(),
  );

  // Ignore trailing open editions the user has not answered yet: they still
  // have time to keep the streak alive.
  let endIndex = sorted.length - 1;
  while (
    endIndex >= 0 &&
    !sorted[endIndex].participated &&
    now.getTime() < sorted[endIndex].endsAt.getTime()
  ) {
    endIndex -= 1;
  }

  let current = 0;
  if (endIndex >= 0 && sorted[endIndex].participated) {
    let index = endIndex;
    while (index >= 0 && sorted[index].participated) {
      current += 1;
      index -= 1;
    }
  }

  let best = 0;
  let run = 0;
  for (const edition of sorted) {
    if (edition.participated) {
      run += 1;
      best = Math.max(best, run);
    } else {
      run = 0;
    }
  }

  const openEditions = sorted.filter(
    (edition) => now.getTime() < edition.endsAt.getTime(),
  );
  const atRiskEdition =
    openEditions
      .filter((edition) => !edition.participated)
      .sort((a, b) => a.endsAt.getTime() - b.endsAt.getTime())[0] ?? null;

  const currentEdition =
    atRiskEdition ??
    [...openEditions].sort(
      (a, b) => b.startsAt.getTime() - a.startsAt.getTime(),
    )[0] ??
    null;

  const status: StreakStatus =
    current === 0 ? 'none' : atRiskEdition ? 'at_risk' : 'active';

  return {
    current,
    best: Math.max(best, current),
    status,
    hasPostedInCurrentEdition: currentEdition?.participated ?? false,
    currentEdition: currentEdition
      ? {
          id: currentEdition.id,
          title: currentEdition.title,
          startsAt: currentEdition.startsAt,
          endsAt: currentEdition.endsAt,
          participated: currentEdition.participated,
        }
      : null,
    participatedEditions: sorted.filter((edition) => edition.participated)
      .length,
  };
}

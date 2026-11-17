export const postInclude = {
  user: {
    select: {
      id: true,
      username: true,
      avatarUrl: true,
      avatarKey: true,
    },
  },
  challenge: {
    select: {
      id: true,
      title: true,
      type: true,
    },
  },
} as const;

export function postIncludeWithUpvotes(userId: number) {
  return {
    ...postInclude,
    _count: {
      select: { upVotes: true },
    },
    upVotes: {
      where: { userId },
      select: { id: true },
    },
    reactions: {
      select: { emoji: true, userId: true },
    },
  };
}

type PostWithUpvoteMeta = {
  _count?: { upVotes: number };
  upVotes?: { id: number }[];
  reactions?: { emoji: string; userId: number }[];
  [key: string]: unknown;
};

export function formatPostWithUpvotes<T extends PostWithUpvoteMeta>(
  post: T,
  userId: number,
) {
  const { _count, upVotes, reactions = [], ...rest } = post;
  const reactionMap = new Map<
    string,
    { count: number; reactedByMe: boolean }
  >();
  for (const reaction of reactions) {
    const current = reactionMap.get(reaction.emoji) ?? {
      count: 0,
      reactedByMe: false,
    };
    current.count += 1;
    current.reactedByMe ||= reaction.userId === userId;
    reactionMap.set(reaction.emoji, current);
  }

  return {
    ...rest,
    upvoteCount: _count?.upVotes ?? 0,
    hasUpvoted: (upVotes?.length ?? 0) > 0,
    reactions: [...reactionMap.entries()]
      .map(([emoji, value]) => ({ emoji, ...value }))
      .sort((a, b) => b.count - a.count),
  };
}

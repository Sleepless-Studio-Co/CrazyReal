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
  };
}

type PostWithUpvoteMeta = {
  _count?: { upVotes: number };
  upVotes?: { id: number }[];
  [key: string]: unknown;
};

export function formatPostWithUpvotes<T extends PostWithUpvoteMeta>(post: T) {
  const { _count, upVotes, ...rest } = post;
  return {
    ...rest,
    upvoteCount: _count?.upVotes ?? 0,
    hasUpvoted: (upVotes?.length ?? 0) > 0,
  };
}

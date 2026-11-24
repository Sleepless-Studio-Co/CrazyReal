import {
  formatPostWithUpvotes,
  postInclude,
  postIncludeWithUpvotes,
} from './post.utils';

describe('post.utils', () => {
  describe('postIncludeWithUpvotes', () => {
    it('adds upvote count, own upvote and reactions to the base include', () => {
      const include = postIncludeWithUpvotes(7);

      expect(include).toEqual({
        ...postInclude,
        _count: { select: { upVotes: true } },
        upVotes: { where: { userId: 7 }, select: { id: true } },
        reactions: { select: { emoji: true, userId: true } },
      });
    });
  });

  describe('formatPostWithUpvotes', () => {
    it('maps upvote metadata and aggregates reactions sorted by count', () => {
      const post = {
        id: 1,
        photoUrl: '/uploads/a.jpg',
        _count: { upVotes: 3 },
        upVotes: [{ id: 11 }],
        reactions: [
          { emoji: '🔥', userId: 1 },
          { emoji: '🔥', userId: 2 },
          { emoji: '😍', userId: 3 },
        ],
      };

      const result = formatPostWithUpvotes(post, 1);

      expect(result).toEqual({
        id: 1,
        photoUrl: '/uploads/a.jpg',
        upvoteCount: 3,
        hasUpvoted: true,
        reactions: [
          { emoji: '🔥', count: 2, reactedByMe: true },
          { emoji: '😍', count: 1, reactedByMe: false },
        ],
      });
    });

    it('defaults to zero upvotes and empty reactions when metadata is absent', () => {
      const result = formatPostWithUpvotes({ id: 2 }, 1);

      expect(result).toEqual({
        id: 2,
        upvoteCount: 0,
        hasUpvoted: false,
        reactions: [],
      });
    });

    it('flags hasUpvoted=false when the current user has no upvote', () => {
      const result = formatPostWithUpvotes(
        { id: 3, _count: { upVotes: 5 }, upVotes: [] },
        1,
      );

      expect(result.hasUpvoted).toBe(false);
      expect(result.upvoteCount).toBe(5);
    });
  });
});

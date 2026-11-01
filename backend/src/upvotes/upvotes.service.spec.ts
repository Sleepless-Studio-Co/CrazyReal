import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { UpVotesService } from './upvotes.service';
import { PrismaService } from '../prisma/prisma.service';

describe('UpVotesService', () => {
  let service: UpVotesService;
  let prismaService: {
    friendship: { findMany: jest.Mock };
    post: { findUnique: jest.Mock };
    upVote: { create: jest.Mock; findUnique: jest.Mock; delete: jest.Mock };
    postReaction: { deleteMany: jest.Mock; create: jest.Mock };
    $transaction: jest.Mock;
  };

  // Raw post shape returned by getFormattedPost before formatting.
  const rawPost = {
    id: 1,
    photoUrl: '/uploads/a.jpg',
    _count: { upVotes: 1 },
    upVotes: [{ id: 5 }],
    reactions: [],
  };
  const formattedPost = {
    id: 1,
    photoUrl: '/uploads/a.jpg',
    upvoteCount: 1,
    hasUpvoted: true,
    reactions: [],
  };

  beforeEach(async () => {
    prismaService = {
      friendship: { findMany: jest.fn() },
      post: { findUnique: jest.fn() },
      upVote: { create: jest.fn(), findUnique: jest.fn(), delete: jest.fn() },
      postReaction: { deleteMany: jest.fn(), create: jest.fn() },
      $transaction: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UpVotesService,
        { provide: PrismaService, useValue: prismaService },
      ],
    }).compile();

    service = module.get<UpVotesService>(UpVotesService);
  });

  const ownPostAccess = () =>
    prismaService.post.findUnique
      .mockResolvedValueOnce({ id: 1, userId: 1, user: { isPrivate: false } })
      .mockResolvedValueOnce(rawPost);

  describe('assertPostInFeed', () => {
    it('throws NotFoundException when the post does not exist', async () => {
      prismaService.post.findUnique.mockResolvedValueOnce(null);
      await expect(service.upvote(1, 999)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('allows upvoting an own private post', async () => {
      prismaService.post.findUnique
        .mockResolvedValueOnce({ id: 1, userId: 1, user: { isPrivate: true } })
        .mockResolvedValueOnce(rawPost);
      prismaService.upVote.create.mockResolvedValue({});

      await expect(service.upvote(1, 1)).resolves.toEqual(formattedPost);
      expect(prismaService.upVote.create).toHaveBeenCalledWith({
        data: { userId: 1, postId: 1 },
      });
    });

    it('throws NotFoundException for a private post from a non-friend', async () => {
      prismaService.post.findUnique.mockResolvedValueOnce({
        id: 1,
        userId: 2,
        user: { isPrivate: true },
      });
      prismaService.friendship.findMany.mockResolvedValue([]);

      await expect(service.upvote(1, 1)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('allows upvoting a private post from an accepted friend', async () => {
      prismaService.post.findUnique
        .mockResolvedValueOnce({ id: 1, userId: 2, user: { isPrivate: true } })
        .mockResolvedValueOnce(rawPost);
      prismaService.friendship.findMany.mockResolvedValue([
        { userId: 1, friendId: 2, status: 'ACCEPTED' },
      ]);
      prismaService.upVote.create.mockResolvedValue({});

      await expect(service.upvote(1, 1)).resolves.toEqual(formattedPost);
    });
  });

  describe('upvote', () => {
    it('creates the upvote and returns the formatted post', async () => {
      ownPostAccess();
      prismaService.upVote.create.mockResolvedValue({});

      await expect(service.upvote(1, 1)).resolves.toEqual(formattedPost);
    });

    it('treats an existing upvote (P2002) as idempotent', async () => {
      ownPostAccess();
      prismaService.upVote.create.mockRejectedValue({ code: 'P2002' });

      await expect(service.upvote(1, 1)).resolves.toEqual(formattedPost);
    });

    it('rethrows unexpected upvote errors', async () => {
      ownPostAccess();
      const boom = new Error('boom');
      prismaService.upVote.create.mockRejectedValue(boom);

      await expect(service.upvote(1, 1)).rejects.toBe(boom);
    });
  });

  describe('removeUpvote', () => {
    it('throws BadRequestException when the user has not upvoted', async () => {
      prismaService.post.findUnique.mockResolvedValueOnce({
        id: 1,
        userId: 1,
        user: { isPrivate: false },
      });
      prismaService.upVote.findUnique.mockResolvedValue(null);

      await expect(service.removeUpvote(1, 1)).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('deletes the upvote and returns the formatted post', async () => {
      prismaService.post.findUnique
        .mockResolvedValueOnce({ id: 1, userId: 1, user: { isPrivate: false } })
        .mockResolvedValueOnce(rawPost);
      prismaService.upVote.findUnique.mockResolvedValue({ id: 5 });
      prismaService.upVote.delete.mockResolvedValue({});

      await expect(service.removeUpvote(1, 1)).resolves.toEqual(formattedPost);
      expect(prismaService.upVote.delete).toHaveBeenCalledWith({
        where: { userId_postId: { userId: 1, postId: 1 } },
      });
    });
  });

  describe('addReaction', () => {
    it('replaces any previous reaction with the new one in a transaction', async () => {
      ownPostAccess();
      prismaService.$transaction.mockResolvedValue([]);

      await expect(service.addReaction(1, 1, '🔥')).resolves.toEqual(
        formattedPost,
      );
      expect(prismaService.$transaction).toHaveBeenCalledWith([
        prismaService.postReaction.deleteMany({
          where: { userId: 1, postId: 1 },
        }),
        prismaService.postReaction.create({
          data: { userId: 1, postId: 1, emoji: '🔥' },
        }),
      ]);
    });
  });

  describe('removeReaction', () => {
    it('deletes the matching reaction and returns the formatted post', async () => {
      ownPostAccess();
      prismaService.postReaction.deleteMany.mockResolvedValue({});

      await expect(service.removeReaction(1, 1, '🔥')).resolves.toEqual(
        formattedPost,
      );
      expect(prismaService.postReaction.deleteMany).toHaveBeenCalledWith({
        where: { userId: 1, postId: 1, emoji: '🔥' },
      });
    });
  });
});

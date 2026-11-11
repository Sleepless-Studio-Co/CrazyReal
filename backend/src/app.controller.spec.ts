import { Test, TestingModule } from '@nestjs/testing';
import { AppController } from './app.controller';
import { PrismaService } from './prisma/prisma.service';
import { FeedGateway } from './feed/feed.gateway';
import { NotFoundException, BadRequestException } from '@nestjs/common';
import { beforeEach, describe, expect, it, jest } from '@jest/globals';

describe('AppController', () => {
  let appController: AppController;
  let prismaService: {
    challenge: {
      findMany: jest.Mock<any>;
    };
    post: {
      create: jest.Mock<any>;
      findMany: jest.Mock<any>;
    };
    friendship: {
      findMany: jest.Mock<any>;
    };
  };
  let feedGateway: {
    broadcastNewPost: jest.Mock<any>;
  };

  beforeEach(async () => {
    prismaService = {
      challenge: {
        findMany: jest.fn(),
      },
      post: {
        create: jest.fn(),
        findMany: jest.fn(),
      },
      friendship: {
        findMany: jest.fn(),
      },
    };
    feedGateway = {
      broadcastNewPost: jest.fn(),
    };

    const app: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [
        {
          provide: PrismaService,
          useValue: prismaService,
        },
        {
          provide: FeedGateway,
          useValue: feedGateway,
        },
      ],
    }).compile();

    appController = app.get<AppController>(AppController);
  });

  describe('getCurrentChallenge', () => {
    it('should return the active challenge from candidates', async () => {
      const now = new Date();
      const challenge = {
        id: 1,
        title: 'Grimace Challenge',
        description: 'Fais une grimace ! 🤪',
        date: new Date(now.getTime() - 60 * 60 * 1000),
        type: 'WEEKLY_A',
        isActive: true,
      };
      prismaService.challenge.findMany.mockResolvedValue([challenge]);

      await expect(appController.getCurrentChallenge()).resolves.toEqual(challenge);
      expect(prismaService.challenge.findMany).toHaveBeenCalled();
    });

    it('should throw NotFoundException when no active challenge exists', async () => {
      prismaService.challenge.findMany.mockResolvedValue([]);

      await expect(appController.getCurrentChallenge()).rejects.toThrow(NotFoundException);
    });
  });

  describe('getNearbyChallenges', () => {
    const user = { userId: 1 } as any;

    it('keeps live and upcoming challenges within the radius, closest first', async () => {
      const now = Date.now();
      const base = {
        type: 'SPECIAL',
        durationHours: null,
        endsAt: null,
        isActive: true,
        registrations: [],
        _count: { registrations: 0 },
      };
      const hour = 60 * 60 * 1000;
      prismaService.challenge.findMany.mockResolvedValue([
        // Tour Eiffel, en cours
        { ...base, id: 1, date: new Date(now - hour), latitude: 48.8584, longitude: 2.2945 },
        // Lyon, hors rayon
        { ...base, id: 2, date: new Date(now - hour), latitude: 45.764, longitude: 4.8357 },
        // Louvre, à venir + inscrit
        { ...base, id: 4, date: new Date(now + hour), latitude: 48.8606, longitude: 2.3376,
          registrations: [{ id: 9 }], _count: { registrations: 3 } },
        // Terminé
        { ...base, id: 5, date: new Date(now - 48 * hour), latitude: 48.853, longitude: 2.35 },
      ]);

      // Notre-Dame
      const result = await appController.getNearbyChallenges(user, '48.853', '2.3499', '30');

      expect(result.map((c) => c.id)).toEqual([4, 1]);
      expect(result[0]).toMatchObject({ isLive: false, registered: true, participants: 3 });
      expect(result[1].isLive).toBe(true);
      expect(result[1].distanceKm).toBeGreaterThan(3);
      expect(result[1].distanceKm).toBeLessThan(5);
    });

    it('rejects invalid coordinates and radius over 30 km', async () => {
      await expect(appController.getNearbyChallenges(user, 'abc', '2', '10')).rejects.toThrow(
        BadRequestException,
      );
      await expect(appController.getNearbyChallenges(user, '48', '2', '31')).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('uploadPhoto', () => {
    it('should associate post with the current active challenge', async () => {
      const now = new Date();
      const challenge = {
        id: 42,
        title: 'Test Challenge',
        description: 'Test',
        date: new Date(now.getTime() - 60 * 60 * 1000),
        type: 'WEEKLY_A',
        isActive: true,
      };
      const file = {
        filename: 'test-image.jpg',
        originalname: 'test.jpg',
      } as Express.Multer.File;
      const user = {
        userId: 123,
        email: 'user@example.com',
        username: 'test-user',
      };

      prismaService.challenge.findMany.mockResolvedValue([challenge]);
      prismaService.post.create.mockResolvedValue({
        id: 1,
        photoUrl: 'http://localhost:3000/uploads/test-image.jpg',
        challengeId: 42,
        userId: 123,
      });

      await appController.uploadPhoto(file, user);

      expect(prismaService.post.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            challengeId: 42,
            userId: 123,
          }),
        }),
      );
    });

    it('should throw BadRequestException when no active challenge exists', async () => {
      const file = { filename: 'test.jpg' } as Express.Multer.File;
      const user = {
        userId: 123,
        email: 'user@example.com',
        username: 'test-user',
      };

      prismaService.challenge.findMany.mockResolvedValue([]);

      await expect(appController.uploadPhoto(file, user)).rejects.toThrow(BadRequestException);
    });
  });

  describe('getPosts', () => {
    it('uses public, accepted-friend, and own authors in the feed filter', async () => {
      prismaService.friendship.findMany.mockResolvedValue([
        { userId: 10, friendId: 20, status: 'ACCEPTED' },
      ]);
      prismaService.challenge.findMany.mockResolvedValue([]);
      prismaService.post.findMany.mockResolvedValue([]);

      await appController.getPosts({
        userId: 10,
        email: 'user@example.com',
        username: 'user',
      });

      expect(prismaService.post.findMany).toHaveBeenCalledWith(expect.objectContaining({
        where: expect.objectContaining({
          OR: [
            { userId: { in: [20, 10] } },
            { user: { isPrivate: false } },
          ],
        }),
      }));
    });
  });

  describe('getTopPosts', () => {
    const user = { userId: 10, email: 'user@example.com', username: 'user' };

    it('ranks upvoted posts of completed global challenges only', async () => {
      const now = Date.now();
      prismaService.challenge.findMany.mockResolvedValue([
        // Terminé : commencé il y a 10 jours, durée 24 h.
        { id: 1, date: new Date(now - 10 * 24 * 3600 * 1000), type: 'SPECIAL', durationHours: null, endsAt: null, isActive: true },
        // En cours : commencé il y a 1 h.
        { id: 2, date: new Date(now - 3600 * 1000), type: 'WEEKLY_A', durationHours: null, endsAt: null, isActive: true },
      ]);
      prismaService.friendship.findMany.mockResolvedValue([
        { userId: 20, friendId: 10, status: 'ACCEPTED' },
      ]);
      prismaService.post.findMany.mockResolvedValue([]);

      await appController.getTopPosts(user);

      expect(prismaService.challenge.findMany).toHaveBeenCalledWith({
        where: expect.objectContaining({ conversationId: null }),
      });
      const query = prismaService.post.findMany.mock.calls[0][0] as any;
      expect(query.where.challengeId).toEqual({ in: [1] });
      expect(query.where.OR).toEqual([
        { userId: { in: [20, 10] } },
        { user: { isPrivate: false } },
      ]);
      expect(query.where.upVotes).toEqual({ some: {} });
      expect(query.where.createdAt).toBeUndefined();
      expect(query.orderBy[0]).toEqual({ upVotes: { _count: 'desc' } });
    });

    it('restricts posts to the requested period', async () => {
      prismaService.challenge.findMany.mockResolvedValue([]);
      prismaService.friendship.findMany.mockResolvedValue([]);
      prismaService.post.findMany.mockResolvedValue([]);

      const before = Date.now();
      await appController.getTopPosts(user, 'week');

      const query = prismaService.post.findMany.mock.calls[0][0] as any;
      const since = query.where.createdAt.gte.getTime();
      expect(before - since).toBeGreaterThanOrEqual(7 * 24 * 3600 * 1000 - 1000);
      expect(before - since).toBeLessThanOrEqual(7 * 24 * 3600 * 1000 + 1000);
    });

    it('rejects an unknown period', async () => {
      await expect(appController.getTopPosts(user, 'year')).rejects.toThrow(BadRequestException);
    });
  });
});

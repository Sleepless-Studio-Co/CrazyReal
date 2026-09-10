import { Test, TestingModule } from '@nestjs/testing';
import { AppController } from './app.controller';
import { PrismaService } from './prisma/prisma.service';
import { NotFoundException, BadRequestException } from '@nestjs/common';
import { FeedGateway } from './feed/feed.gateway';

describe('AppController', () => {
  let appController: AppController;
  let prismaService: {
    challenge: {
      findMany: jest.Mock;
    };
    post: {
      create: jest.Mock;
    };
  };
  let feedGateway: {
    broadcastNewPost: jest.Mock;
  };

  beforeEach(async () => {
    prismaService = {
      challenge: {
        findMany: jest.fn(),
      },
      post: {
        create: jest.fn(),
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

      const i18n = { t: jest.fn().mockResolvedValue('') } as unknown as Parameters<AppController['getCurrentChallenge']>[0];
      await expect(appController.getCurrentChallenge(i18n)).resolves.toEqual(challenge);
      expect(prismaService.challenge.findMany).toHaveBeenCalled();
    });

    it('should throw NotFoundException when no active challenge exists', async () => {
      prismaService.challenge.findMany.mockResolvedValue([]);

      const i18n = { t: jest.fn().mockResolvedValue('') } as unknown as Parameters<AppController['getCurrentChallenge']>[0];
      await expect(appController.getCurrentChallenge(i18n)).rejects.toThrow(NotFoundException);
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
      const user = { userId: 123 };
      const i18n = { t: jest.fn().mockResolvedValue('') } as any;

      prismaService.challenge.findMany.mockResolvedValue([challenge]);
      prismaService.post.create.mockResolvedValue({
        id: 1,
        photoUrl: 'http://localhost:3000/uploads/test-image.jpg',
        challengeId: 42,
        userId: 123,
      });

      await appController.uploadPhoto(file, user, i18n);

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
      const user = { userId: 123 };
      const i18n = { t: jest.fn().mockResolvedValue('') } as any;

      prismaService.challenge.findMany.mockResolvedValue([]);

      await expect(appController.uploadPhoto(file, user, i18n)).rejects.toThrow(BadRequestException);
    });
  });
});

import { Test, TestingModule } from '@nestjs/testing';
import { AppController } from './app.controller';
import { PrismaService } from './prisma/prisma.service';

describe('AppController', () => {
  let appController: AppController;
  let prismaService: {
    challenge: {
      findMany: jest.Mock;
    };
  };

  beforeEach(async () => {
    prismaService = {
      challenge: {
        findMany: jest.fn(),
      },
    };

    const app: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [
        {
          provide: PrismaService,
          useValue: prismaService,
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
  });
});

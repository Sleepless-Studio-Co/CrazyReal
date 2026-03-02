import { Test, TestingModule } from '@nestjs/testing';
import { AppController } from './app.controller';
import { PrismaService } from './prisma/prisma.service';

describe('AppController', () => {
  let appController: AppController;
  let prismaService: {
    challenge: {
      findUnique: jest.Mock;
      create: jest.Mock;
    };
  };

  beforeEach(async () => {
    prismaService = {
      challenge: {
        findUnique: jest.fn(),
        create: jest.fn(),
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
    it('should return the existing challenge', async () => {
      const challenge = { id: 1, content: 'Fais une grimace ! 🤪', isActive: true };
      prismaService.challenge.findUnique.mockResolvedValue(challenge);

      await expect(appController.getCurrentChallenge()).resolves.toEqual(challenge);
      expect(prismaService.challenge.findUnique).toHaveBeenCalledWith({ where: { id: 1 } });
      expect(prismaService.challenge.create).not.toHaveBeenCalled();
    });
  });
});

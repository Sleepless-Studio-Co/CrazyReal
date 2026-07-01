import { Test, TestingModule } from '@nestjs/testing';
import { FriendsController } from './friends.controller';
import { FriendsService } from './friends.service';
import { PrismaService } from '../prisma/prisma.service';

describe('FriendsController', () => {
  let controller: FriendsController;
  let prismaService: {
    user: {
      findUnique: jest.Mock;
    };
    friendship: {
      findFirst: jest.Mock;
      create: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
      delete: jest.Mock;
      findMany: jest.Mock;
    };
  };

  beforeEach(async () => {
    prismaService = {
      user: {
        findUnique: jest.fn(),
      },
      friendship: {
        findFirst: jest.fn(),
        create: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
        findMany: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [FriendsController],
      providers: [
        FriendsService,
        {
          provide: PrismaService,
          useValue: prismaService,
        },
      ],
    }).compile();

    controller = module.get<FriendsController>(FriendsController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});

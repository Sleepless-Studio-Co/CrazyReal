import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { FriendsService } from './friends.service';
import { PrismaService } from '../prisma/prisma.service';

describe('FriendsService', () => {
  let service: FriendsService;
  let prismaService: {
    user: {
      findUnique: jest.Mock;
    };
    friendship: {
      findFirst: jest.Mock;
      create: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
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
        findMany: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FriendsService,
        {
          provide: PrismaService,
          useValue: prismaService,
        },
      ],
    }).compile();

    service = module.get<FriendsService>(FriendsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('sendFriendRequest', () => {
    it('should throw NotFoundException when target user does not exist', async () => {
      prismaService.user.findUnique.mockResolvedValue(null);

      await expect(service.sendFriendRequest(1, 'unknown')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(prismaService.user.findUnique).toHaveBeenCalledWith({
        where: { username: 'unknown' },
      });
    });

    it('should throw BadRequestException when sending request to self', async () => {
      prismaService.user.findUnique.mockResolvedValue({ id: 1, username: 'alice' });

      await expect(service.sendFriendRequest(1, 'alice')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('should create a pending request when target is valid and no relation exists', async () => {
      prismaService.user.findUnique.mockResolvedValue({ id: 2, username: 'bob' });
      prismaService.friendship.findFirst.mockResolvedValue(null);
      prismaService.friendship.create.mockResolvedValue({
        id: 10,
        userId: 1,
        friendId: 2,
        status: 'PENDING',
      });

      const result = await service.sendFriendRequest(1, 'bob');

      expect(prismaService.friendship.create).toHaveBeenCalledWith({
        data: {
          userId: 1,
          friendId: 2,
          status: 'PENDING',
        },
      });
      expect(result).toEqual({
        id: 10,
        userId: 1,
        friendId: 2,
        status: 'PENDING',
      });
    });
  });
});
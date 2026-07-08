import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
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

    it('should throw ForbiddenException when the target has blocked the user', async () => {
      prismaService.user.findUnique.mockResolvedValue({ id: 2, username: 'bob' });
      prismaService.friendship.findFirst.mockResolvedValue({
        id: 5,
        userId: 2,
        friendId: 1,
        status: 'BLOCKED',
      });

      await expect(service.sendFriendRequest(1, 'bob')).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });
  });

  describe('acceptFriendRequest', () => {
    it('should throw BadRequestException when the request is not pending', async () => {
      prismaService.friendship.findUnique.mockResolvedValue({
        id: 1,
        friendId: 1,
        status: 'ACCEPTED',
      });

      await expect(service.acceptFriendRequest(1, 1)).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('should accept a pending request', async () => {
      prismaService.friendship.findUnique.mockResolvedValue({
        id: 1,
        friendId: 1,
        status: 'PENDING',
      });
      prismaService.friendship.update.mockResolvedValue({ id: 1, status: 'ACCEPTED' });

      const result = await service.acceptFriendRequest(1, 1);

      expect(result).toEqual({ id: 1, status: 'ACCEPTED' });
    });
  });

  describe('rejectFriendRequest', () => {
    it('should delete a pending request', async () => {
      prismaService.friendship.findUnique.mockResolvedValue({
        id: 1,
        friendId: 1,
        status: 'PENDING',
      });

      const result = await service.rejectFriendRequest(1, 1);

      expect(prismaService.friendship.delete).toHaveBeenCalledWith({ where: { id: 1 } });
      expect(result).toEqual({ success: true });
    });

    it('should throw NotFoundException when not authorized', async () => {
      prismaService.friendship.findUnique.mockResolvedValue({ id: 1, friendId: 99, status: 'PENDING' });

      await expect(service.rejectFriendRequest(1, 1)).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('blockUser', () => {
    it('should create a BLOCKED relation when none exists', async () => {
      prismaService.user.findUnique.mockResolvedValue({ id: 2, username: 'bob' });
      prismaService.friendship.findFirst.mockResolvedValue(null);
      prismaService.friendship.create.mockResolvedValue({ id: 1, status: 'BLOCKED' });

      const result = await service.blockUser(1, 'bob');

      expect(prismaService.friendship.create).toHaveBeenCalledWith({
        data: { userId: 1, friendId: 2, status: 'BLOCKED' },
      });
      expect(result).toEqual({ id: 1, status: 'BLOCKED' });
    });

    it('should update an existing relation to BLOCKED', async () => {
      prismaService.user.findUnique.mockResolvedValue({ id: 2, username: 'bob' });
      prismaService.friendship.findFirst.mockResolvedValue({ id: 7, userId: 2, friendId: 1, status: 'ACCEPTED' });
      prismaService.friendship.update.mockResolvedValue({ id: 7, status: 'BLOCKED' });

      const result = await service.blockUser(1, 'bob');

      expect(prismaService.friendship.update).toHaveBeenCalledWith({
        where: { id: 7 },
        data: { userId: 1, friendId: 2, status: 'BLOCKED' },
      });
      expect(result).toEqual({ id: 7, status: 'BLOCKED' });
    });
  });
});
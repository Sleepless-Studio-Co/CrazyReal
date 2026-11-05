import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { FriendsService } from './friends.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationGateway } from '../bootstrap/notification.gateway';

describe('FriendsService', () => {
  let notificationGateway: { sendToUser: jest.Mock };
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
    notificationGateway = { sendToUser: jest.fn() };
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
        {
          provide: NotificationGateway,
          useValue: notificationGateway,
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
        requester: { username: 'alice' },
      });

      const result = await service.sendFriendRequest(1, 'bob');

      expect(prismaService.friendship.create).toHaveBeenCalledWith({
        data: {
          userId: 1,
          friendId: 2,
          status: 'PENDING',
        },
        include: {
          requester: { select: { username: true } },
        },
      });
      expect(notificationGateway.sendToUser).toHaveBeenCalledWith(2, 'friendRequestReceived', {
        requesterUsername: 'alice',
      });
      expect(result).toEqual({
        id: 10,
        userId: 1,
        friendId: 2,
        status: 'PENDING',
        requester: { username: 'alice' },
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

  describe('sendFriendRequest (relations existantes)', () => {
    it('should look for a relation in both directions', async () => {
      prismaService.user.findUnique.mockResolvedValue({ id: 2, username: 'bob' });
      prismaService.friendship.findFirst.mockResolvedValue(null);
      prismaService.friendship.create.mockResolvedValue({ requester: { username: 'alice' } });

      await service.sendFriendRequest(1, 'bob');

      expect(prismaService.friendship.findFirst).toHaveBeenCalledWith({
        where: {
          OR: [
            { userId: 1, friendId: 2 },
            { userId: 2, friendId: 1 },
          ],
        },
      });
    });

    it.each(['PENDING', 'ACCEPTED'])(
      'should refuse a new request when a %s relation already exists',
      async (status) => {
        prismaService.user.findUnique.mockResolvedValue({ id: 2, username: 'bob' });
        prismaService.friendship.findFirst.mockResolvedValue({ id: 3, userId: 2, friendId: 1, status });

        await expect(service.sendFriendRequest(1, 'bob')).rejects.toBeInstanceOf(
          BadRequestException,
        );
        expect(prismaService.friendship.create).not.toHaveBeenCalled();
        expect(notificationGateway.sendToUser).not.toHaveBeenCalled();
      },
    );

    it('should not notify anyone when the target is blocked', async () => {
      prismaService.user.findUnique.mockResolvedValue({ id: 2, username: 'bob' });
      prismaService.friendship.findFirst.mockResolvedValue({ id: 5, status: 'BLOCKED' });

      await expect(service.sendFriendRequest(1, 'bob')).rejects.toBeInstanceOf(ForbiddenException);
      expect(notificationGateway.sendToUser).not.toHaveBeenCalled();
    });
  });

  describe('acceptFriendRequest (autorisations)', () => {
    it('should throw NotFoundException when the request does not exist', async () => {
      prismaService.friendship.findUnique.mockResolvedValue(null);

      await expect(service.acceptFriendRequest(1, 42)).rejects.toBeInstanceOf(NotFoundException);
      expect(prismaService.friendship.update).not.toHaveBeenCalled();
    });

    it('should not let the requester accept their own request', async () => {
      // Alice (1) a envoyé la demande à Bob (2) : seule Bob peut l'accepter.
      prismaService.friendship.findUnique.mockResolvedValue({
        id: 9,
        userId: 1,
        friendId: 2,
        status: 'PENDING',
      });

      await expect(service.acceptFriendRequest(1, 9)).rejects.toBeInstanceOf(NotFoundException);
      expect(prismaService.friendship.update).not.toHaveBeenCalled();
    });

    it('should set the status to ACCEPTED on the right request', async () => {
      prismaService.friendship.findUnique.mockResolvedValue({ id: 9, userId: 1, friendId: 2, status: 'PENDING' });
      prismaService.friendship.update.mockResolvedValue({ id: 9, status: 'ACCEPTED' });

      await service.acceptFriendRequest(2, 9);

      expect(prismaService.friendship.update).toHaveBeenCalledWith({
        where: { id: 9 },
        data: { status: 'ACCEPTED' },
      });
    });
  });

  describe('rejectFriendRequest (cas limites)', () => {
    it('should throw NotFoundException when the request does not exist', async () => {
      prismaService.friendship.findUnique.mockResolvedValue(null);

      await expect(service.rejectFriendRequest(1, 42)).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should refuse to delete a request that is no longer pending', async () => {
      // Sinon "refuser" une amitié acceptée la supprimerait silencieusement.
      prismaService.friendship.findUnique.mockResolvedValue({ id: 1, friendId: 1, status: 'ACCEPTED' });

      await expect(service.rejectFriendRequest(1, 1)).rejects.toBeInstanceOf(BadRequestException);
      expect(prismaService.friendship.delete).not.toHaveBeenCalled();
    });
  });

  describe('blockUser (cas limites)', () => {
    it('should throw NotFoundException for an unknown username', async () => {
      prismaService.user.findUnique.mockResolvedValue(null);

      await expect(service.blockUser(1, 'ghost')).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should not let a user block themselves', async () => {
      prismaService.user.findUnique.mockResolvedValue({ id: 1, username: 'alice' });

      await expect(service.blockUser(1, 'alice')).rejects.toBeInstanceOf(BadRequestException);
      expect(prismaService.friendship.create).not.toHaveBeenCalled();
    });
  });

  describe('getFriends', () => {
    it('should only query ACCEPTED friendships in both directions', async () => {
      prismaService.friendship.findMany.mockResolvedValue([]);

      await service.getFriends(1);

      expect(prismaService.friendship.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { status: 'ACCEPTED', OR: [{ userId: 1 }, { friendId: 1 }] },
        }),
      );
    });

    it('should return the other user of each friendship without the password', async () => {
      const alice = { id: 1, username: 'alice', password: 'hash-a' };
      const bob = { id: 2, username: 'bob', password: 'hash-b' };
      const carol = { id: 3, username: 'carol', password: 'hash-c' };
      prismaService.friendship.findMany.mockResolvedValue([
        { userId: 1, friendId: 2, requester: alice, receiver: bob },
        { userId: 3, friendId: 1, requester: carol, receiver: alice },
      ]);

      const friends = await service.getFriends(1);

      expect(friends).toEqual([
        { id: 2, username: 'bob' },
        { id: 3, username: 'carol' },
      ]);
    });
  });

  describe('getPendingRequests', () => {
    it('should list only requests received by the user', async () => {
      prismaService.friendship.findMany.mockResolvedValue([]);

      await service.getPendingRequests(2);

      expect(prismaService.friendship.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { friendId: 2, status: 'PENDING' } }),
      );
    });

    it('should expose requestId and the requester without the password', async () => {
      const createdAt = new Date('2026-01-01');
      prismaService.friendship.findMany.mockResolvedValue([
        { id: 4, createdAt, requester: { id: 1, username: 'alice', password: 'hash' } },
      ]);

      const requests = await service.getPendingRequests(2);

      expect(requests).toEqual([
        { requestId: 4, requester: { id: 1, username: 'alice' }, createdAt },
      ]);
    });
  });
});

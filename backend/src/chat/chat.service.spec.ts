import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { ChatService } from './chat.service';
import { PrismaService } from '../prisma/prisma.service';

describe('ChatService', () => {
  let service: ChatService;
  let prismaService: {
    conversation: {
      create: jest.Mock;
      findMany: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
      delete: jest.Mock;
    };
    participant: {
      findUnique: jest.Mock;
      findMany: jest.Mock;
      delete: jest.Mock;
    };
    friendship: {
      findMany: jest.Mock;
    };
    message: {
      create: jest.Mock;
      findMany: jest.Mock;
    };
  };

  beforeEach(async () => {
    prismaService = {
      conversation: {
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      participant: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        delete: jest.fn(),
      },
      friendship: {
        findMany: jest.fn(),
      },
      message: {
        create: jest.fn(),
        findMany: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ChatService,
        {
          provide: PrismaService,
          useValue: prismaService,
        },
      ],
    }).compile();

    service = module.get<ChatService>(ChatService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('createGroup', () => {
    it('should reject members who are not accepted friends', async () => {
      prismaService.friendship.findMany.mockResolvedValue([]);

      await expect(service.createGroup(1, 'Group', [2, 3])).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(prismaService.conversation.create).not.toHaveBeenCalled();
    });

    it('should create the group when all members are accepted friends', async () => {
      prismaService.friendship.findMany.mockResolvedValue([
        { userId: 1, friendId: 2, status: 'ACCEPTED' },
        { userId: 3, friendId: 1, status: 'ACCEPTED' },
      ]);
      prismaService.conversation.create.mockResolvedValue({ id: 1, isGroup: true });

      const result = await service.createGroup(1, 'Group', [2, 3]);

      expect(prismaService.conversation.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ ownerId: 1 }),
        }),
      );
      expect(result).toEqual({ id: 1, isGroup: true });
    });
  });

  describe('leaveGroup', () => {
    it('should throw NotFoundException when conversation does not exist', async () => {
      prismaService.conversation.findUnique.mockResolvedValue(null);

      await expect(service.leaveGroup(1, 1)).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should throw ForbiddenException when user is not a participant', async () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true, ownerId: 1 });
      prismaService.participant.findUnique.mockResolvedValue(null);

      await expect(service.leaveGroup(1, 2)).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('should delete the conversation when the last participant leaves', async () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true, ownerId: 1 });
      prismaService.participant.findUnique.mockResolvedValue({ id: 10, userId: 1, conversationId: 1 });
      prismaService.participant.findMany.mockResolvedValue([]);

      const result = await service.leaveGroup(1, 1);

      expect(prismaService.conversation.delete).toHaveBeenCalledWith({ where: { id: 1 } });
      expect(result).toEqual({ success: true, deleted: true });
    });

    it('should transfer ownership when the owner leaves a non-empty group', async () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true, ownerId: 1 });
      prismaService.participant.findUnique.mockResolvedValue({ id: 10, userId: 1, conversationId: 1 });
      prismaService.participant.findMany.mockResolvedValue([{ id: 11, userId: 2, conversationId: 1 }]);

      await service.leaveGroup(1, 1);

      expect(prismaService.conversation.update).toHaveBeenCalledWith({
        where: { id: 1 },
        data: { ownerId: 2 },
      });
    });
  });

  describe('removeMember', () => {
    it('should throw ForbiddenException when requester is not the owner', async () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true, ownerId: 1 });

      await expect(service.removeMember(1, 2, 3)).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('should remove the member when requester is the owner', async () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true, ownerId: 1 });
      prismaService.participant.findUnique.mockResolvedValue({ id: 12, userId: 3, conversationId: 1 });

      const result = await service.removeMember(1, 1, 3);

      expect(prismaService.participant.delete).toHaveBeenCalledWith({ where: { id: 12 } });
      expect(result).toEqual({ success: true });
    });
  });

  describe('getMessages', () => {
    it('should throw ForbiddenException when user is not a participant', async () => {
      prismaService.participant.findUnique.mockResolvedValue(null);

      await expect(service.getMessages(1, 2)).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('should paginate using the cursor and return messages in chronological order', async () => {
      prismaService.participant.findUnique.mockResolvedValue({ id: 1 });
      prismaService.message.findMany.mockResolvedValue([{ id: 5 }, { id: 4 }]);

      const result = await service.getMessages(1, 2, 30, 6);

      expect(prismaService.message.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { conversationId: 1, id: { lt: 6 } },
          take: 30,
        }),
      );
      expect(result).toEqual([{ id: 4 }, { id: 5 }]);
    });
  });
});

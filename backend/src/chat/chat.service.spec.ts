import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { ChatService } from './chat.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationGateway } from '../bootstrap/notification.gateway';

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
      createMany: jest.Mock;
      update: jest.Mock;
      delete: jest.Mock;
      count: jest.Mock;
    };
    friendship: {
      findMany: jest.Mock;
    };
    message: {
      create: jest.Mock;
      findMany: jest.Mock;
    };
    challenge: {
      create: jest.Mock;
      findMany: jest.Mock;
      findUnique: jest.Mock;
      delete: jest.Mock;
    };
    post: {
      deleteMany: jest.Mock;
    };
    $executeRaw: jest.Mock;
    $transaction: jest.Mock;
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
        createMany: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
        count: jest.fn(),
      },
      friendship: {
        findMany: jest.fn(),
      },
      message: {
        create: jest.fn(),
        findMany: jest.fn(),
      },
      challenge: {
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        delete: jest.fn(),
      },
      post: {
        deleteMany: jest.fn(),
      },
      $executeRaw: jest.fn(),
      // Le callback reçoit le mock lui-même comme client de transaction.
      $transaction: jest.fn((fn) => fn(prismaService)),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ChatService,
        {
          provide: PrismaService,
          useValue: prismaService,
        },
        {
          provide: NotificationGateway,
          useValue: {
            sendToUsers: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<ChatService>(ChatService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getMembers', () => {
    it('should throw ForbiddenException when user is not a participant', async () => {
      prismaService.participant.findUnique.mockResolvedValue(null);

      await expect(service.getMembers(1, 2)).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('should return the participants when user has access', async () => {
      prismaService.participant.findUnique.mockResolvedValue({ id: 1 });
      prismaService.participant.findMany.mockResolvedValue([
        { id: 1, role: 'ADMIN', user: { id: 1, username: 'alice' } },
      ]);

      const result = await service.getMembers(1, 1);

      expect(result).toEqual([{ id: 1, role: 'ADMIN', user: { id: 1, username: 'alice' } }]);
    });
  });

  describe('createGroup', () => {
    it('should reject members who are not accepted friends', async () => {
      prismaService.friendship.findMany.mockResolvedValue([]);

      await expect(service.createGroup(1, 'Group', [2, 3])).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(prismaService.conversation.create).not.toHaveBeenCalled();
    });

    it('should create the group with the creator as ADMIN and others as MEMBER', async () => {
      prismaService.friendship.findMany.mockResolvedValue([
        { userId: 1, friendId: 2, status: 'ACCEPTED' },
        { userId: 3, friendId: 1, status: 'ACCEPTED' },
      ]);
      prismaService.conversation.create.mockResolvedValue({ id: 1, isGroup: true });

      const result = await service.createGroup(1, 'Group', [2, 3]);

      expect(prismaService.conversation.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            participants: {
              create: [
                { userId: 1, role: 'ADMIN' },
                { userId: 2, role: 'MEMBER' },
                { userId: 3, role: 'MEMBER' },
              ],
            },
          }),
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
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true });
      prismaService.participant.findUnique.mockResolvedValue(null);

      await expect(service.leaveGroup(1, 2)).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('should delete the conversation when the last participant leaves', async () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true });
      prismaService.participant.findUnique.mockResolvedValue({ id: 10, userId: 1, conversationId: 1, role: 'ADMIN' });
      prismaService.participant.findMany.mockResolvedValue([]);

      const result = await service.leaveGroup(1, 1);

      expect(prismaService.conversation.delete).toHaveBeenCalledWith({ where: { id: 1 } });
      expect(result).toEqual({ success: true, deleted: true });
    });

    it('should promote the oldest remaining member when the last admin leaves', async () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true });
      prismaService.participant.findUnique.mockResolvedValue({ id: 10, userId: 1, conversationId: 1, role: 'ADMIN' });
      prismaService.participant.findMany.mockResolvedValue([
        { id: 11, userId: 2, conversationId: 1, role: 'MEMBER' },
      ]);

      await service.leaveGroup(1, 1);

      expect(prismaService.participant.update).toHaveBeenCalledWith({
        where: { id: 11 },
        data: { role: 'ADMIN' },
      });
    });

    it('should not touch roles when an admin remains', async () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true });
      prismaService.participant.findUnique.mockResolvedValue({ id: 10, userId: 1, conversationId: 1, role: 'ADMIN' });
      prismaService.participant.findMany.mockResolvedValue([
        { id: 11, userId: 2, conversationId: 1, role: 'ADMIN' },
        { id: 12, userId: 3, conversationId: 1, role: 'MEMBER' },
      ]);

      await service.leaveGroup(1, 1);

      expect(prismaService.participant.update).not.toHaveBeenCalled();
    });
  });

  describe('removeMember', () => {
    it('should throw ForbiddenException when requester is not an admin', async () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true });
      prismaService.participant.findUnique.mockResolvedValue({ id: 1, userId: 2, conversationId: 1, role: 'MEMBER' });

      await expect(service.removeMember(1, 2, 3)).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('should remove the member when requester is an admin', async () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true });
      prismaService.participant.findUnique
        .mockResolvedValueOnce({ id: 1, userId: 1, conversationId: 1, role: 'ADMIN' })
        .mockResolvedValueOnce({ id: 12, userId: 3, conversationId: 1, role: 'MEMBER' });

      const result = await service.removeMember(1, 1, 3);

      expect(prismaService.participant.delete).toHaveBeenCalledWith({ where: { id: 12 } });
      expect(result).toEqual({ success: true });
    });
  });

  describe('addMembers', () => {
    const asAdmin = () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true });
      prismaService.participant.findUnique.mockResolvedValue({
        id: 1,
        userId: 1,
        conversationId: 1,
        role: 'ADMIN',
      });
    };

    it('should throw ForbiddenException when requester is not an admin', async () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true });
      prismaService.participant.findUnique.mockResolvedValue({ id: 1, userId: 2, conversationId: 1, role: 'MEMBER' });

      await expect(service.addMembers(1, 2, [3])).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('should reject users who are not accepted friends', async () => {
      asAdmin();
      prismaService.participant.findMany.mockResolvedValue([{ userId: 1 }]);
      prismaService.friendship.findMany.mockResolvedValue([]);

      await expect(service.addMembers(1, 1, [3])).rejects.toBeInstanceOf(BadRequestException);
      expect(prismaService.participant.createMany).not.toHaveBeenCalled();
    });

    it('should throw BadRequestException when everyone is already in the group', async () => {
      asAdmin();
      prismaService.participant.findMany.mockResolvedValue([{ userId: 1 }, { userId: 3 }]);

      await expect(service.addMembers(1, 1, [3, 3])).rejects.toBeInstanceOf(BadRequestException);
      expect(prismaService.participant.createMany).not.toHaveBeenCalled();
    });

    it('should refuse to go over the 50 member cap', async () => {
      asAdmin();
      prismaService.participant.findMany.mockResolvedValue(
        Array.from({ length: 50 }, (_, i) => ({ userId: i + 1 })),
      );

      await expect(service.addMembers(1, 1, [99])).rejects.toBeInstanceOf(BadRequestException);
      expect(prismaService.participant.createMany).not.toHaveBeenCalled();
    });

    it('should add the new friends as MEMBER and skip existing ones', async () => {
      asAdmin();
      prismaService.participant.findMany
        // état courant du groupe, puis la liste renvoyée par getMembers
        .mockResolvedValueOnce([{ userId: 1 }, { userId: 3 }])
        .mockResolvedValueOnce([{ user: { id: 1 } }, { user: { id: 3 } }, { user: { id: 4 } }]);
      prismaService.friendship.findMany.mockResolvedValue([
        { userId: 1, friendId: 4, status: 'ACCEPTED' },
      ]);

      const result = await service.addMembers(1, 1, [3, 4, 4]);

      expect(prismaService.participant.createMany).toHaveBeenCalledWith({
        data: [{ userId: 4, conversationId: 1, role: 'MEMBER' }],
        skipDuplicates: true,
      });
      expect(result).toHaveLength(3);
    });
  });

  describe('promoteMember', () => {
    it('should throw ForbiddenException when requester is not an admin', async () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true });
      prismaService.participant.findUnique.mockResolvedValue({ id: 1, userId: 2, conversationId: 1, role: 'MEMBER' });

      await expect(service.promoteMember(1, 2, 3)).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('should promote a member to admin', async () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true });
      prismaService.participant.findUnique
        .mockResolvedValueOnce({ id: 1, userId: 1, conversationId: 1, role: 'ADMIN' })
        .mockResolvedValueOnce({ id: 12, userId: 3, conversationId: 1, role: 'MEMBER' });
      prismaService.participant.update.mockResolvedValue({ id: 12, role: 'ADMIN' });

      const result = await service.promoteMember(1, 1, 3);

      expect(prismaService.participant.update).toHaveBeenCalledWith({
        where: { id: 12 },
        data: { role: 'ADMIN' },
      });
      expect(result).toEqual({ id: 12, role: 'ADMIN' });
    });
  });

  describe('demoteMember', () => {
    it('should throw BadRequestException when demoting the last admin', async () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true });
      prismaService.participant.findUnique
        .mockResolvedValueOnce({ id: 1, userId: 1, conversationId: 1, role: 'ADMIN' })
        .mockResolvedValueOnce({ id: 12, userId: 3, conversationId: 1, role: 'ADMIN' });
      prismaService.participant.count.mockResolvedValue(1);

      await expect(service.demoteMember(1, 1, 3)).rejects.toBeInstanceOf(BadRequestException);
    });

    it('should demote an admin when another admin remains', async () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: true });
      prismaService.participant.findUnique
        .mockResolvedValueOnce({ id: 1, userId: 1, conversationId: 1, role: 'ADMIN' })
        .mockResolvedValueOnce({ id: 12, userId: 3, conversationId: 1, role: 'ADMIN' });
      prismaService.participant.count.mockResolvedValue(2);
      prismaService.participant.update.mockResolvedValue({ id: 12, role: 'MEMBER' });

      const result = await service.demoteMember(1, 1, 3);

      expect(prismaService.participant.update).toHaveBeenCalledWith({
        where: { id: 12 },
        data: { role: 'MEMBER' },
      });
      expect(result).toEqual({ id: 12, role: 'MEMBER' });
    });
  });

  describe('createGroupChallenge', () => {
    const future = new Date(Date.now() + 60 * 60 * 1000);

    it('should throw ForbiddenException when user is not a participant', async () => {
      prismaService.participant.findUnique.mockResolvedValue(null);

      await expect(
        service.createGroupChallenge(1, 2, 'Défi', '', future),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(prismaService.challenge.create).not.toHaveBeenCalled();
    });

    it('should throw BadRequestException when endsAt is in the past', async () => {
      prismaService.participant.findUnique.mockResolvedValue({ id: 1 });
      const past = new Date(Date.now() - 1000);

      await expect(
        service.createGroupChallenge(1, 1, 'Défi', '', past),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(prismaService.challenge.create).not.toHaveBeenCalled();
    });

    it('should create the challenge scoped to the conversation', async () => {
      prismaService.participant.findUnique.mockResolvedValue({ id: 1 });
      prismaService.challenge.create.mockResolvedValue({ id: 7 });

      const result = await service.createGroupChallenge(1, 1, 'Défi', 'desc', future);

      expect(prismaService.challenge.create).toHaveBeenCalledWith({
        data: {
          title: 'Défi',
          description: 'desc',
          conversationId: 1,
          endsAt: future,
          creatorId: 1,
        },
      });
      expect(result).toEqual({ id: 7 });
    });
  });

  describe('getGroupChallenges', () => {
    it('should flag challenges the user can delete', async () => {
      prismaService.participant.findUnique.mockResolvedValue({ id: 1, role: 'MEMBER' });
      prismaService.challenge.findMany.mockResolvedValue([
        { id: 1, creatorId: 2 },
        { id: 2, creatorId: 3 },
      ]);

      const result = await service.getGroupChallenges(1, 2);

      expect(result).toEqual([
        { id: 1, creatorId: 2, canDelete: true },
        { id: 2, creatorId: 3, canDelete: false },
      ]);
    });

    it('should let admins delete every challenge', async () => {
      prismaService.participant.findUnique.mockResolvedValue({ id: 1, role: 'ADMIN' });
      prismaService.challenge.findMany.mockResolvedValue([{ id: 1, creatorId: null }]);

      const result = await service.getGroupChallenges(1, 2);

      expect(result).toEqual([{ id: 1, creatorId: null, canDelete: true }]);
    });
  });

  describe('deleteGroupChallenge', () => {
    it('should throw ForbiddenException when user is not a participant', async () => {
      prismaService.participant.findUnique.mockResolvedValue(null);

      await expect(service.deleteGroupChallenge(1, 7, 2)).rejects.toBeInstanceOf(ForbiddenException);
      expect(prismaService.challenge.delete).not.toHaveBeenCalled();
    });

    it('should throw NotFoundException when the challenge belongs to another group', async () => {
      prismaService.participant.findUnique.mockResolvedValue({ id: 1, role: 'ADMIN' });
      prismaService.challenge.findUnique.mockResolvedValue({ id: 7, conversationId: 99, creatorId: 2 });

      await expect(service.deleteGroupChallenge(1, 7, 2)).rejects.toBeInstanceOf(NotFoundException);
      expect(prismaService.challenge.delete).not.toHaveBeenCalled();
    });

    it('should throw ForbiddenException when a member deletes someone else\'s challenge', async () => {
      prismaService.participant.findUnique.mockResolvedValue({ id: 1, role: 'MEMBER' });
      prismaService.challenge.findUnique.mockResolvedValue({ id: 7, conversationId: 1, creatorId: 3 });

      await expect(service.deleteGroupChallenge(1, 7, 2)).rejects.toBeInstanceOf(ForbiddenException);
      expect(prismaService.challenge.delete).not.toHaveBeenCalled();
    });

    it('should delete the challenge and its posts for its creator', async () => {
      prismaService.participant.findUnique.mockResolvedValue({ id: 1, role: 'MEMBER' });
      prismaService.challenge.findUnique.mockResolvedValue({ id: 7, conversationId: 1, creatorId: 2 });

      const result = await service.deleteGroupChallenge(1, 7, 2);

      expect(prismaService.post.deleteMany).toHaveBeenCalledWith({ where: { challengeId: 7 } });
      expect(prismaService.challenge.delete).toHaveBeenCalledWith({ where: { id: 7 } });
      expect(result).toEqual({ success: true });
    });

    it('should let a group admin delete any challenge', async () => {
      prismaService.participant.findUnique.mockResolvedValue({ id: 1, role: 'ADMIN' });
      prismaService.challenge.findUnique.mockResolvedValue({ id: 7, conversationId: 1, creatorId: 3 });

      await service.deleteGroupChallenge(1, 7, 2);

      expect(prismaService.challenge.delete).toHaveBeenCalledWith({ where: { id: 7 } });
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

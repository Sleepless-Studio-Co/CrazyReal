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
    };
    post: {
      findMany: jest.Mock;
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
      },
      post: {
        findMany: jest.fn(),
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
        },
      });
      expect(result).toEqual({ id: 7 });
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

  describe('createGroup (règles de composition)', () => {
    it('should refuse a group with only the creator', async () => {
      await expect(service.createGroup(1, 'Solo', [])).rejects.toBeInstanceOf(BadRequestException);
      expect(prismaService.conversation.create).not.toHaveBeenCalled();
    });

    it('should not count the creator twice when they add themselves', async () => {
      await expect(service.createGroup(1, 'Solo', [1, 1])).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('should refuse more than 50 members', async () => {
      const ids = Array.from({ length: 50 }, (_, i) => i + 2);

      await expect(service.createGroup(1, 'Big', ids)).rejects.toBeInstanceOf(BadRequestException);
      expect(prismaService.friendship.findMany).not.toHaveBeenCalled();
    });

    it('should deduplicate members before creating the group', async () => {
      prismaService.friendship.findMany.mockResolvedValue([{ userId: 1, friendId: 2, status: 'ACCEPTED' }]);
      prismaService.conversation.create.mockResolvedValue({ id: 1 });

      await service.createGroup(1, 'Duo', [2, 2, 1]);

      expect(prismaService.conversation.create.mock.calls[0][0].data.participants.create).toEqual([
        { userId: 1, role: 'ADMIN' },
        { userId: 2, role: 'MEMBER' },
      ]);
    });

    it('should name every member who is not a friend in the error', async () => {
      prismaService.friendship.findMany.mockResolvedValue([{ userId: 2, friendId: 1, status: 'ACCEPTED' }]);

      await expect(service.createGroup(1, 'G', [2, 3, 4])).rejects.toThrow(/3, 4/);
    });

    it('should only accept ACCEPTED friendships, in both directions', async () => {
      prismaService.friendship.findMany.mockResolvedValue([]);

      await expect(service.createGroup(1, 'G', [2])).rejects.toBeInstanceOf(BadRequestException);
      expect(prismaService.friendship.findMany).toHaveBeenCalledWith({
        where: {
          status: 'ACCEPTED',
          OR: [
            { userId: 1, friendId: { in: [2] } },
            { friendId: 1, userId: { in: [2] } },
          ],
        },
      });
    });
  });

  describe('getConversations', () => {
    it('should only return conversations the user takes part in, paginated', async () => {
      prismaService.conversation.findMany.mockResolvedValue([]);

      await service.getConversations(1, 3, 10);

      expect(prismaService.conversation.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { participants: { some: { userId: 1 } } },
          skip: 20,
          take: 10,
        }),
      );
    });

    it('should expose participants without private fields', async () => {
      prismaService.conversation.findMany.mockResolvedValue([]);

      await service.getConversations(1);

      const select = prismaService.conversation.findMany.mock.calls[0][0].include.participants.include.user.select;
      expect(select).toEqual({ id: true, username: true, avatarUrl: true, avatarKey: true });
    });
  });

  describe('getGroupFeed', () => {
    it('should throw ForbiddenException for a non-member', async () => {
      prismaService.participant.findUnique.mockResolvedValue(null);

      await expect(service.getGroupFeed(1, 9)).rejects.toBeInstanceOf(ForbiddenException);
      expect(prismaService.post.findMany).not.toHaveBeenCalled();
    });

    it('should only return posts of this group challenges with upvote info', async () => {
      prismaService.participant.findUnique.mockResolvedValue({ id: 1 });
      prismaService.post.findMany.mockResolvedValue([
        { id: 5, _count: { upVotes: 2 }, upVotes: [] },
      ]);

      const posts = await service.getGroupFeed(7, 1);

      const query = prismaService.post.findMany.mock.calls[0][0];
      expect(query.where).toEqual({ challenge: { is: { conversationId: 7 } } });
      expect(query.include.upVotes.where).toEqual({ userId: 1 });
      expect(posts).toEqual([{ id: 5, upvoteCount: 2, hasUpvoted: false }]);
    });
  });

  describe('getGroupChallenges', () => {
    it('should throw ForbiddenException for a non-member', async () => {
      prismaService.participant.findUnique.mockResolvedValue(null);

      await expect(service.getGroupChallenges(1, 9)).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('should list the group challenges, newest first', async () => {
      prismaService.participant.findUnique.mockResolvedValue({ id: 1 });
      prismaService.challenge.findMany.mockResolvedValue([{ id: 3 }]);

      await expect(service.getGroupChallenges(7, 1)).resolves.toEqual([{ id: 3 }]);
      expect(prismaService.challenge.findMany).toHaveBeenCalledWith({
        where: { conversationId: 7 },
        orderBy: { date: 'desc' },
      });
    });
  });

  describe('actions admin sur une conversation invalide', () => {
    it('should throw NotFoundException when the conversation does not exist', async () => {
      prismaService.conversation.findUnique.mockResolvedValue(null);

      await expect(service.removeMember(1, 1, 3)).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should refuse admin actions on a private (1-to-1) conversation', async () => {
      prismaService.conversation.findUnique.mockResolvedValue({ id: 1, isGroup: false });

      await expect(service.promoteMember(1, 1, 3)).rejects.toBeInstanceOf(BadRequestException);
      expect(prismaService.participant.update).not.toHaveBeenCalled();
    });
  });
});

import { PrismaService } from '../prisma/prisma.service';
import { Injectable, BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { formatPostWithUpvotes, postIncludeWithUpvotes } from '../posts/post.utils';

@Injectable()
export class ChatService {
  constructor(private prisma: PrismaService) {}

  async getConversationIdsForUser(userId: number): Promise<number[]> {
    const participations = await this.prisma.participant.findMany({
      where: { userId },
      select: { conversationId: true },
    });
    return participations.map((p) => p.conversationId);
  }

  async isParticipant(conversationId: number, userId: number): Promise<boolean> {
    const participant = await this.prisma.participant.findUnique({
      where: {
        userId_conversationId: {
          userId,
          conversationId,
        },
      },
    });

    return !!participant;
  }

  async getMembers(conversationId: number, userId: number) {
    const isParticipant = await this.isParticipant(conversationId, userId);
    if (!isParticipant) {
      throw new ForbiddenException("Tu n'as pas accès à ce groupe.");
    }

    return this.prisma.participant.findMany({
      where: { conversationId },
      orderBy: { joinedAt: 'asc' },
      include: {
        user: {
          select: {
            id: true,
            username: true,
          },
        },
      },
    });
  }

  async createGroup(creatorId: number, name: string, participantIds: number[]) {
    const uniqueParticipantIds = [...new Set(participantIds)].filter(
      (id) => id !== creatorId,
    );
    const totalMembers = uniqueParticipantIds.length + 1;

    if (totalMembers < 2) {
      throw new BadRequestException("Un groupe doit avoir au moins 2 membres.");
    }

    if (totalMembers > 50) {
      throw new BadRequestException("Un groupe ne peut pas dépasser 50 membres.");
    }

    const acceptedFriendships = await this.prisma.friendship.findMany({
      where: {
        status: 'ACCEPTED',
        OR: [
          { userId: creatorId, friendId: { in: uniqueParticipantIds } },
          { friendId: creatorId, userId: { in: uniqueParticipantIds } },
        ],
      },
    });

    const friendIds = new Set(
      acceptedFriendships.map((f) => (f.userId === creatorId ? f.friendId : f.userId)),
    );

    const invalidIds = uniqueParticipantIds.filter((id) => !friendIds.has(id));
    if (invalidIds.length > 0) {
      throw new BadRequestException(
        `Les utilisateurs suivants ne sont pas dans ta liste d'amis : ${invalidIds.join(', ')}.`,
      );
    }

    return this.prisma.conversation.create({
      data: {
        isGroup: true,
        name: name,
        participants: {
          create: [
            { userId: creatorId, role: 'ADMIN' },
            ...uniqueParticipantIds.map((id) => ({ userId: id, role: 'MEMBER' as const })),
          ],
        },
      },
      include: {
        participants: {
          include: {
            user: {
              select: {
                id: true,
                username: true,
              },
            },
          },
        },
      },
    });
  }

  async getConversations(userId: number, page = 1, limit = 20) {
    return this.prisma.conversation.findMany({
      where: {
        participants: {
          some: {
            userId: userId,
          },
        },
      },
      include: {
        participants: {
          include: {
            user: {
              select: {
                id: true,
                username: true,
              },
            },
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      skip: (page - 1) * limit,
      take: limit,
    });
  }

  async leaveGroup(conversationId: number, userId: number) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
    });

    if (!conversation) {
      throw new NotFoundException('Conversation introuvable.');
    }

    if (!conversation.isGroup) {
      throw new BadRequestException('Tu ne peux pas quitter une conversation privée.');
    }

    const participant = await this.prisma.participant.findUnique({
      where: { userId_conversationId: { userId, conversationId } },
    });

    if (!participant) {
      throw new ForbiddenException("Tu ne fais pas partie de ce groupe.");
    }

    await this.prisma.participant.delete({ where: { id: participant.id } });

    const remaining = await this.prisma.participant.findMany({
      where: { conversationId },
      orderBy: { joinedAt: 'asc' },
    });

    if (remaining.length === 0) {
      await this.prisma.conversation.delete({ where: { id: conversationId } });
      return { success: true, deleted: true };
    }

    const hasRemainingAdmin = remaining.some((p) => p.role === 'ADMIN');
    if (participant.role === 'ADMIN' && !hasRemainingAdmin) {
      await this.prisma.participant.update({
        where: { id: remaining[0].id },
        data: { role: 'ADMIN' },
      });
    }

    return { success: true, deleted: false };
  }

  private async requireAdmin(conversationId: number, userId: number) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
    });

    if (!conversation) {
      throw new NotFoundException('Conversation introuvable.');
    }

    if (!conversation.isGroup) {
      throw new BadRequestException("Cette action n'est possible que sur un groupe.");
    }

    const requester = await this.prisma.participant.findUnique({
      where: { userId_conversationId: { userId, conversationId } },
    });

    if (!requester || requester.role !== 'ADMIN') {
      throw new ForbiddenException("Seul un admin du groupe peut effectuer cette action.");
    }

    return conversation;
  }

  async removeMember(conversationId: number, requesterId: number, memberId: number) {
    await this.requireAdmin(conversationId, requesterId);

    if (memberId === requesterId) {
      throw new BadRequestException('Utilise la sortie de groupe pour te retirer toi-même.');
    }

    const participant = await this.prisma.participant.findUnique({
      where: { userId_conversationId: { userId: memberId, conversationId } },
    });

    if (!participant) {
      throw new NotFoundException("Cet utilisateur ne fait pas partie du groupe.");
    }

    await this.prisma.participant.delete({ where: { id: participant.id } });
    return { success: true };
  }

  async promoteMember(conversationId: number, requesterId: number, memberId: number) {
    await this.requireAdmin(conversationId, requesterId);

    const participant = await this.prisma.participant.findUnique({
      where: { userId_conversationId: { userId: memberId, conversationId } },
    });

    if (!participant) {
      throw new NotFoundException("Cet utilisateur ne fait pas partie du groupe.");
    }

    return this.prisma.participant.update({
      where: { id: participant.id },
      data: { role: 'ADMIN' },
    });
  }

  async demoteMember(conversationId: number, requesterId: number, memberId: number) {
    await this.requireAdmin(conversationId, requesterId);

    const participant = await this.prisma.participant.findUnique({
      where: { userId_conversationId: { userId: memberId, conversationId } },
    });

    if (!participant) {
      throw new NotFoundException("Cet utilisateur ne fait pas partie du groupe.");
    }

    if (participant.role === 'MEMBER') {
      return participant;
    }

    const adminCount = await this.prisma.participant.count({
      where: { conversationId, role: 'ADMIN' },
    });

    if (adminCount <= 1) {
      throw new BadRequestException('Le groupe doit garder au moins un admin.');
    }

    return this.prisma.participant.update({
      where: { id: participant.id },
      data: { role: 'MEMBER' },
    });
  }

  async createGroupChallenge(
    conversationId: number,
    userId: number,
    title: string,
    description: string,
    endsAt: Date,
  ) {
    const isParticipant = await this.isParticipant(conversationId, userId);
    if (!isParticipant) {
      throw new ForbiddenException("Tu n'as pas accès à ce groupe.");
    }

    if (endsAt.getTime() <= Date.now()) {
      throw new BadRequestException("La date de fin doit être dans le futur.");
    }

    return this.prisma.challenge.create({
      data: {
        title,
        description,
        conversationId,
        endsAt,
        // date = now : le défi démarre à sa création (fenêtre [date, endsAt]).
      },
    });
  }

  async getGroupChallenges(conversationId: number, userId: number) {
    const isParticipant = await this.isParticipant(conversationId, userId);
    if (!isParticipant) {
      throw new ForbiddenException("Tu n'as pas accès à ce groupe.");
    }

    return this.prisma.challenge.findMany({
      where: { conversationId },
      orderBy: { date: 'desc' },
    });
  }

  async getGroupFeed(conversationId: number, userId: number) {
    const isParticipant = await this.isParticipant(conversationId, userId);
    if (!isParticipant) {
      throw new ForbiddenException("Tu n'as pas accès à ce groupe.");
    }

    const posts = await this.prisma.post.findMany({
      where: { challenge: { is: { conversationId } } },
      orderBy: { createdAt: 'desc' },
      include: postIncludeWithUpvotes(userId),
    });

    return posts.map(formatPostWithUpvotes);
  }

  async sendMessage(conversationId: number, senderId: number, content: string) {
    const isParticipant = await this.prisma.participant.findUnique({
      where: {
        userId_conversationId: {
          userId: senderId,
          conversationId: conversationId,
        },
      },
    });

    if (!isParticipant) {
      throw new ForbiddenException("Tu ne fais pas partie de cette discussion.");
    }

    return this.prisma.message.create({
      data: {
        content: content,
        senderId: senderId,
        conversationId: conversationId,
      },
      include: {
        sender: {
          select: {
            id: true,
            username: true,
          },
        },
      },
    });
  }

  async getMessages(conversationId: number, userId: number, limit = 30, cursor?: number, after?: number) {
    const isParticipant = await this.prisma.participant.findUnique({
      where: {
        userId_conversationId: {
          userId: userId,
          conversationId: conversationId,
        },
      },
    });

    if (!isParticipant) {
      throw new ForbiddenException("Tu n'as pas accès à ces messages.");
    }

    const idFilter = cursor ? { lt: cursor } : after ? { gt: after } : undefined;

    const messages = await this.prisma.message.findMany({
      where: {
        conversationId: conversationId,
        ...(idFilter ? { id: idFilter } : {}),
      },
      orderBy: { id: after ? 'asc' : 'desc' },
      take: limit,
      include: {
        sender: {
          select: {
            id: true,
            username: true,
          },
        },
      },
    });

    // `after` already returns ascending (oldest→newest); cursor/initial need reversal
    return after ? messages : messages.reverse();
  }
}
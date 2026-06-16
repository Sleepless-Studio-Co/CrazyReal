import { PrismaService } from '../prisma/prisma.service';
import { Injectable, BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';

@Injectable()
export class ChatService {
  constructor(private prisma: PrismaService) {}

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
        ownerId: creatorId,
        participants: {
          create: [
            { userId: creatorId },
            ...uniqueParticipantIds.map((id) => ({ userId: id })),
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

    const remaining = await this.prisma.participant.findMany({ where: { conversationId } });

    if (remaining.length === 0) {
      await this.prisma.conversation.delete({ where: { id: conversationId } });
      return { success: true, deleted: true };
    }

    if (conversation.ownerId === userId) {
      await this.prisma.conversation.update({
        where: { id: conversationId },
        data: { ownerId: remaining[0].userId },
      });
    }

    return { success: true, deleted: false };
  }

  async removeMember(conversationId: number, requesterId: number, memberId: number) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
    });

    if (!conversation) {
      throw new NotFoundException('Conversation introuvable.');
    }

    if (!conversation.isGroup) {
      throw new BadRequestException("Cette action n'est possible que sur un groupe.");
    }

    if (conversation.ownerId !== requesterId) {
      throw new ForbiddenException("Seul le créateur du groupe peut retirer un membre.");
    }

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

  async getMessages(conversationId: number, userId: number, limit = 30, cursor?: number) {
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

    const messages = await this.prisma.message.findMany({
      where: {
        conversationId: conversationId,
        ...(cursor ? { id: { lt: cursor } } : {}),
      },
      orderBy: {
        id: 'desc',
      },
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

    return messages.reverse();
  }
}
import { PrismaService } from '../prisma/prisma.service';
import { Injectable, BadRequestException, ForbiddenException } from '@nestjs/common';

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

    return this.prisma.conversation.create({
      data: {
        isGroup: true,
        name: name,
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

  async getConversations(userId: number) {
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
    });
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

  async getMessages(conversationId: number, userId: number) {
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

    return this.prisma.message.findMany({
      where: {
        conversationId: conversationId,
      },
      orderBy: {
        createdAt: 'asc',
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
}
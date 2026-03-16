import { PrismaService } from '../prisma/prisma.service';
import { Injectable, BadRequestException, ForbiddenException } from '@nestjs/common';

@Injectable()
export class ChatService {
  constructor(private prisma: PrismaService) {}

  async createGroup(creatorId: number, name: string, participantIds: number[]) {
    // 1. Validation du nombre de participants (2 à 50)
    // On ajoute +1 pour compter le créateur qui n'est généralement pas dans la liste envoyée
    const totalMembers = participantIds.length + 1;

    if (totalMembers < 2) {
      throw new BadRequestException("Un groupe doit avoir au moins 2 membres.");
    }

    if (totalMembers > 50) {
      throw new BadRequestException("Un groupe ne peut pas dépasser 50 membres.");
    }

    // 2. Création de la conversation et des participants en une seule transaction
    return this.prisma.conversation.create({
      data: {
        isGroup: true,
        name: name,
        participants: {
          create: [
            // On ajoute le créateur
            { userId: creatorId },
            // On ajoute tous les amis sélectionnés
            ...participantIds.map((id) => ({ userId: id })),
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

  // Récupérer toutes les conversations d'un utilisateur
  async getConversations(userId: number) {
    return this.prisma.conversation.findMany({
      where: {
        // On cherche les conversations où l'utilisateur fait partie des participants
        participants: {
          some: {
            userId: userId,
          },
        },
      },
      include: {
        // On inclut les informations des participants pour pouvoir afficher leurs pseudos
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
      // On trie par date de création (les plus récentes en premier)
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  // 1. Envoyer un message
  async sendMessage(conversationId: number, senderId: number, content: string) {
    // Sécurité : on vérifie que l'utilisateur fait bien partie de la conversation
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

    // On crée le message et on renvoie aussi le pseudo de l'expéditeur pour l'affichage
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

  // 2. Récupérer l'historique des messages
  async getMessages(conversationId: number, userId: number) {
    // Sécurité : même vérification
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

    // On récupère les messages triés du plus ancien au plus récent
    return this.prisma.message.findMany({
      where: {
        conversationId: conversationId,
      },
      orderBy: {
        createdAt: 'asc', // L'ordre chronologique naturel d'un chat
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
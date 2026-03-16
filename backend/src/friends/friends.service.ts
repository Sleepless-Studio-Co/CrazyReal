import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class FriendsService {
  constructor(private prisma: PrismaService) {}

  // 1. Envoyer une demande d'ami via le pseudo
  async sendFriendRequest(currentUserId: number, targetUsername: string) {
    // Étape A : Trouver l'utilisateur cible par son pseudo
    const targetUser = await this.prisma.user.findUnique({
      where: { username: targetUsername },
    });

    if (!targetUser) {
      throw new NotFoundException("Utilisateur introuvable avec ce pseudo.");
    }

    const friendId = targetUser.id;

    if (currentUserId === friendId) {
      throw new BadRequestException("Tu ne peux pas t'ajouter en ami.");
    }

    // Étape B : Vérifier si une relation existe déjà
    const existingRequest = await this.prisma.friendship.findFirst({
      where: {
        OR: [
          { userId: currentUserId, friendId: friendId },
          { userId: friendId, friendId: currentUserId },
        ],
      },
    });

    if (existingRequest) {
      throw new BadRequestException("Une demande ou une relation existe déjà.");
    }

    // Étape C : Créer la demande
    return this.prisma.friendship.create({
      data: {
        userId: currentUserId,
        friendId: friendId,
        status: 'PENDING',
      },
    });
  }

  async acceptFriendRequest(userId: number, requestId: number) {
    const request = await this.prisma.friendship.findUnique({
      where: { id: requestId },
    });

    if (!request || request.friendId !== userId) {
      throw new NotFoundException("Demande introuvable ou non autorisée.");
    }

    return this.prisma.friendship.update({
      where: { id: requestId },
      data: { status: 'ACCEPTED' },
    });
  }

  async getFriends(userId: number) {
    const friendships = await this.prisma.friendship.findMany({
      where: {
        status: 'ACCEPTED',
        OR: [{ userId: userId }, { friendId: userId }],
      },
      include: {
        requester: true,
        receiver: true, 
      },
    });

    return friendships.map((f) => {
      const friend = f.userId === userId ? f.receiver : f.requester;
      const { password, ...friendData } = friend;
      return friendData;
    });
  }

  // 4. Récupérer les demandes d'amis en attente (reçues)
  async getPendingRequests(userId: number) {
    const requests = await this.prisma.friendship.findMany({
      where: {
        friendId: userId, // On cherche les demandes qui t'ont été envoyées
        status: 'PENDING',
      },
      include: {
        requester: true, // On récupère les infos de la personne qui a fait la demande
      },
    });

    // On formate la réponse proprement et on cache le mot de passe
    return requests.map((req) => {
      const { password, ...requesterData } = req.requester;
      return {
        requestId: req.id, // L'ID de la relation Friendship (très important pour pouvoir l'accepter ensuite)
        requester: requesterData,
        createdAt: req.createdAt,
      };
    });
  }
}
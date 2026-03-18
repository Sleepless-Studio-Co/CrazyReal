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

  async getPendingRequests(userId: number) {
    const requests = await this.prisma.friendship.findMany({
      where: {
        friendId: userId,
        status: 'PENDING',
      },
      include: {
        requester: true,
      },
    });

    return requests.map((req) => {
      const { password, ...requesterData } = req.requester;
      return {
        requestId: req.id,
        requester: requesterData,
        createdAt: req.createdAt,
      };
    });
  }
}
import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationGateway } from '../bootstrap/notification.gateway';

@Injectable()
export class FriendsService {
  constructor(
    private prisma: PrismaService,
    private notificationGateway: NotificationGateway,
  ) {}

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

    if (existingRequest?.status === 'BLOCKED') {
      throw new ForbiddenException("Impossible d'envoyer une demande à cet utilisateur.");
    }

    if (existingRequest) {
      throw new BadRequestException("Une demande ou une relation existe déjà.");
    }

    // Étape C : Créer la demande
    const friendship = await this.prisma.friendship.create({
      data: {
        userId: currentUserId,
        friendId: friendId,
        status: 'PENDING',
      },
      include: {
        requester: true,
      },
    });

    // Notify target user
    this.notificationGateway.sendToUser(friendId, 'friendRequestReceived', {
      requesterUsername: friendship.requester.username,
    });

    return friendship;
  }

  async acceptFriendRequest(userId: number, requestId: number) {
    const request = await this.prisma.friendship.findUnique({
      where: { id: requestId },
    });

    if (!request || request.friendId !== userId) {
      throw new NotFoundException("Demande introuvable ou non autorisée.");
    }

    if (request.status !== 'PENDING') {
      throw new BadRequestException("Cette demande n'est plus en attente.");
    }

    return this.prisma.friendship.update({
      where: { id: requestId },
      data: { status: 'ACCEPTED' },
    });
  }

  async rejectFriendRequest(userId: number, requestId: number) {
    const request = await this.prisma.friendship.findUnique({
      where: { id: requestId },
    });

    if (!request || request.friendId !== userId) {
      throw new NotFoundException("Demande introuvable ou non autorisée.");
    }

    if (request.status !== 'PENDING') {
      throw new BadRequestException("Cette demande n'est plus en attente.");
    }

    await this.prisma.friendship.delete({ where: { id: requestId } });
    return { success: true };
  }

  async blockUser(currentUserId: number, targetUsername: string) {
    const targetUser = await this.prisma.user.findUnique({
      where: { username: targetUsername },
    });

    if (!targetUser) {
      throw new NotFoundException("Utilisateur introuvable avec ce pseudo.");
    }

    if (currentUserId === targetUser.id) {
      throw new BadRequestException("Tu ne peux pas te bloquer toi-même.");
    }

    const existingRequest = await this.prisma.friendship.findFirst({
      where: {
        OR: [
          { userId: currentUserId, friendId: targetUser.id },
          { userId: targetUser.id, friendId: currentUserId },
        ],
      },
    });

    if (existingRequest) {
      return this.prisma.friendship.update({
        where: { id: existingRequest.id },
        data: { userId: currentUserId, friendId: targetUser.id, status: 'BLOCKED' },
      });
    }

    return this.prisma.friendship.create({
      data: {
        userId: currentUserId,
        friendId: targetUser.id,
        status: 'BLOCKED',
      },
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
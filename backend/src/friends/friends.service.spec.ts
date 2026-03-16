import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class FriendsService {
  constructor(private prisma: PrismaService) {}

  async sendFriendRequest(userId: number, friendId: number) {
    if (userId === friendId) {
      throw new BadRequestException("Tu ne peux pas t'ajouter en ami.");
    }

    const existingRequest = await this.prisma.friendship.findFirst({
      where: {
        OR: [
          { userId: userId, friendId: friendId },
          { userId: friendId, friendId: userId },
        ],
      },
    });

    if (existingRequest) {
      throw new BadRequestException("Une demande ou une relation existe déjà.");
    }

    return this.prisma.friendship.create({
      data: {
        userId,
        friendId,
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
}
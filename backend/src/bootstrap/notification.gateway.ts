import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { JWT_CONFIG_KEYS } from '../auth/jwt.config';
import type { JwtPayload } from '../auth/interfaces/jwt-payload.interface';
import { PrismaService } from '../prisma/prisma.service';

@WebSocketGateway({
  namespace: '/notifications',
  cors: { origin: '*' },
})
@Injectable()
export class NotificationGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private reminderTimer?: NodeJS.Timeout;
  private readonly sentReminderKeys = new Set<string>();

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  @WebSocketServer()
  server: Server;

  // Map userId to socket IDs
  private userSockets: Map<number, string[]> = new Map();

  async handleConnection(client: Socket) {
    const token = this.extractToken(client);
    if (!token) {
      client.disconnect();
      return;
    }

    try {
      const payload = await this.jwtService.verifyAsync<JwtPayload>(token, {
        secret: this.configService.getOrThrow<string>(JWT_CONFIG_KEYS.secret),
      });
      const userId = payload.sub;

      const sockets = this.userSockets.get(userId) || [];
      sockets.push(client.id);
      this.userSockets.set(userId, sockets);
      console.log(`[notif] User ${userId} connected (${client.id})`);
    } catch {
      client.disconnect();
    }
  }

  private extractToken(client: Socket): string | null {
    const authToken = client.handshake.auth?.token;
    if (typeof authToken === 'string' && authToken.startsWith('Bearer ')) {
      return authToken.slice(7);
    }
    if (typeof authToken === 'string' && authToken.length > 0) {
      return authToken;
    }
    return null;
  }

  handleDisconnect(client: Socket) {
    for (const [userId, sockets] of this.userSockets.entries()) {
      const index = sockets.indexOf(client.id);
      if (index !== -1) {
        sockets.splice(index, 1);
        if (sockets.length === 0) {
          this.userSockets.delete(userId);
        } else {
          this.userSockets.set(userId, sockets);
        }
        break;
      }
    }
  }

  onModuleInit() {
    this.reminderTimer = setInterval(() => {
      void this.sendChallengeReminders();
    }, 60_000);
    void this.sendChallengeReminders();
  }

  onModuleDestroy() {
    if (this.reminderTimer) clearInterval(this.reminderTimer);
  }

  sendToUser(userId: number, event: string, data: any) {
    const sockets = this.userSockets.get(userId);
    if (sockets) {
      sockets.forEach((socketId) => {
        this.server.to(socketId).emit(event, data);
      });
    }
  }

  broadcast(event: string, data: any) {
    this.server?.emit(event, data);
  }

  async sendToUsers(userIds: number[], event: string, data: any) {
    for (const userId of userIds) this.sendToUser(userId, event, data);
  }

  private async sendChallengeReminders() {
    const now = new Date();
    const challenges = await this.prisma.challenge.findMany({
      where: { isActive: true, date: { lte: now } },
      include: {
        conversation: {
          select: { participants: { select: { userId: true } } },
        },
      },
    });

    for (const challenge of challenges) {
      const durationHours =
        challenge.durationHours ?? (challenge.type === 'SPECIAL' ? 24 : 84);
      const endsAt = challenge.endsAt ?? new Date(
        challenge.date.getTime() + durationHours * 60 * 60 * 1000,
      );
      const remainingMs = endsAt.getTime() - now.getTime();
      if (remainingMs <= 0) continue;

      for (const thresholdHours of [24, 1]) {
        const thresholdMs = thresholdHours * 60 * 60 * 1000;
        if (remainingMs > thresholdMs || remainingMs <= thresholdMs - 120_000) {
          continue;
        }

        const key = `${challenge.id}:${thresholdHours}`;
        if (this.sentReminderKeys.has(key)) continue;
        this.sentReminderKeys.add(key);

        const userIds = challenge.conversation
          ? challenge.conversation.participants.map((participant) => participant.userId)
          : [...this.userSockets.keys()];
        await this.sendToUsers(userIds, 'challengeReminder', {
          challengeId: challenge.id,
          challengeTitle: challenge.title,
          hoursRemaining: thresholdHours,
          isGlobal: challenge.conversationId == null,
        });
      }
    }
  }
}

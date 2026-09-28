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

@WebSocketGateway({
  namespace: '/notifications',
  cors: { origin: '*' },
})
@Injectable()
export class NotificationGateway implements OnGatewayConnection, OnGatewayDisconnect {
  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
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

  sendToUser(userId: number, event: string, data: any) {
    const sockets = this.userSockets.get(userId);
    if (sockets) {
      sockets.forEach((socketId) => {
        this.server.to(socketId).emit(event, data);
      });
    }
  }
}

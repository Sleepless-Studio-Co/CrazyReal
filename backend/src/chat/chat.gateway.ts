import 'dotenv/config';
import { UseGuards } from '@nestjs/common';
import { WebSocketGateway, WebSocketServer, SubscribeMessage, MessageBody, ConnectedSocket } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { ChatService } from './chat.service';
import { WsJwtAuthGuard } from '../auth/ws-jwt-auth.guard';
import type { ValidatedUser } from '../auth/interfaces/auth-user.interface';

// Les clients mobiles natifs ne sont pas concernés par CORS ; cette restriction
// protège uniquement les clients web (Flutter Web) du gateway temps réel.
const allowedOrigins = process.env.CHAT_CORS_ORIGIN
  ? process.env.CHAT_CORS_ORIGIN.split(',').map((origin) => origin.trim())
  : false;

@WebSocketGateway({ cors: { origin: allowedOrigins } })
export class ChatGateway {
  constructor(private readonly chatService: ChatService) {}

  @WebSocketServer()
  server: Server;

  @UseGuards(WsJwtAuthGuard)
  @SubscribeMessage('joinRoom')
  async handleJoinRoom(@ConnectedSocket() client: Socket, @MessageBody() conversationId: number) {
    const user = client.data.user as ValidatedUser | undefined;
    if (!user) {
      client.emit('joinRoomError', 'Non authentifié');
      return;
    }

    const isParticipant = await this.chatService.isParticipant(conversationId, user.userId);
    if (!isParticipant) {
      client.emit('joinRoomError', 'Accès refusé à cette conversation');
      return;
    }

    client.join(conversationId.toString());
    console.log(`Un utilisateur a rejoint la discussion ${conversationId}`);
  }

  broadcastNewMessage(conversationId: number, message: any) {
    this.server.to(conversationId.toString()).emit('newMessage', message);
  }
}
import 'dotenv/config';
import { WebSocketGateway, WebSocketServer, SubscribeMessage, MessageBody, ConnectedSocket, OnGatewayConnection } from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Server, Socket } from 'socket.io';
import { ChatService } from './chat.service';
import { JWT_CONFIG_KEYS } from '../auth/jwt.config';
import type { JwtPayload } from '../auth/interfaces/jwt-payload.interface';
import type { ValidatedUser } from '../auth/interfaces/auth-user.interface';

// Les clients mobiles natifs ne sont pas concernés par CORS ; cette restriction
// protège uniquement les clients web (Flutter Web) du gateway temps réel.
// Note : le middleware `cors` traite `origin: false` comme "pas de restriction"
// (il ajoute `Access-Control-Allow-Origin: *`), donc on retombe sur `true`
// (même comportement que le CORS REST dans main.ts) quand la variable n'est pas définie.
const allowedOrigins = process.env.CHAT_CORS_ORIGIN
  ? process.env.CHAT_CORS_ORIGIN.split(',').map((origin) => origin.trim())
  : true;

// pingInterval/pingTimeout courts : sur réseau mobile/émulateur le websocket
// peut mourir silencieusement ; on veut détecter la coupure en ~15 s (et non
// ~70 s) pour reconnecter et re-synchroniser vite.
@WebSocketGateway({ namespace: '/chat', cors: { origin: allowedOrigins }, pingTimeout: 10000, pingInterval: 5000 })
export class ChatGateway implements OnGatewayConnection {
  constructor(
    private readonly chatService: ChatService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  @WebSocketServer()
  server: Server;

  async handleConnection(client: Socket) {
    const token = this.extractToken(client);
    if (!token) {
      console.warn(`[ws-auth] Connexion WebSocket ${client.id} refusée : aucun token fourni.`);
      client.disconnect();
      return;
    }

    try {
      const payload = await this.jwtService.verifyAsync<JwtPayload>(token, {
        secret: this.configService.getOrThrow<string>(JWT_CONFIG_KEYS.secret),
      });
      const user = { userId: payload.sub, email: payload.email, username: payload.username } satisfies ValidatedUser;
      client.data.user = user;

      // Auto-join toutes les conversations de l'utilisateur dès la connexion, pour
      // qu'il reçoive `newMessage` même sans avoir la conversation ouverte (liste,
      // badges, notifications). `joinRoom` reste utile pour les conversations créées
      // après la connexion.
      const conversationIds = await this.chatService.getConversationIdsForUser(user.userId);
      for (const id of conversationIds) {
        client.join(id.toString());
      }
      console.log(`[chat] ${user.username} connecté (${client.id}) → ${conversationIds.length} conversations rejointes`);
    } catch {
      console.warn(`[ws-auth] Connexion WebSocket ${client.id} refusée : token invalide ou expiré.`);
      client.disconnect();
    }
  }

  private extractToken(client: Socket): string | null {
    const authHeader = client.handshake.headers?.authorization;
    if (typeof authHeader === 'string' && authHeader.startsWith('Bearer ')) {
      return authHeader.slice(7);
    }

    const authToken = client.handshake.auth?.token;
    if (typeof authToken === 'string' && authToken.startsWith('Bearer ')) {
      return authToken.slice(7);
    }

    if (typeof authToken === 'string' && authToken.length > 0) {
      return authToken;
    }

    return null;
  }

  @SubscribeMessage('joinRoom')
  async handleJoinRoom(@ConnectedSocket() client: Socket, @MessageBody() conversationId: number) {
    const user = client.data.user as ValidatedUser | undefined;
    if (!user) {
      client.emit('joinRoomError', 'Non authentifié');
      return;
    }

    const isParticipant = await this.chatService.isParticipant(conversationId, user.userId);
    if (!isParticipant) {
      console.warn(`[chat] joinRoom refusé pour ${user.username} sur la conversation ${conversationId}`);
      client.emit('joinRoomError', 'Accès refusé à cette conversation');
      return;
    }

    client.join(conversationId.toString());
    client.emit('joinRoomSuccess', { conversationId });
    console.log(`[chat] ${user.username} a rejoint la discussion ${conversationId}`);
  }

  @SubscribeMessage('typing')
  async handleTyping(@ConnectedSocket() client: Socket, @MessageBody() conversationId: number) {
    const user = client.data.user as ValidatedUser | undefined;
    if (!user) return;

    const isParticipant = await this.chatService.isParticipant(conversationId, user.userId);
    if (!isParticipant) return;

    client.to(conversationId.toString()).emit('userTyping', {
      conversationId,
      userId: user.userId,
      username: user.username,
    });
  }

  @SubscribeMessage('stopTyping')
  async handleStopTyping(@ConnectedSocket() client: Socket, @MessageBody() conversationId: number) {
    const user = client.data.user as ValidatedUser | undefined;
    if (!user) return;

    client.to(conversationId.toString()).emit('userStoppedTyping', {
      conversationId,
      userId: user.userId,
      username: user.username,
    });
  }

  broadcastNewMessage(conversationId: number, message: any) {
    const room = conversationId.toString();
    console.log(`[chat] broadcast newMessage → room ${room} messageId=${(message as any).id}`);
    this.server.to(room).emit('newMessage', message);
  }
}
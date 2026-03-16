import { WebSocketGateway, WebSocketServer, SubscribeMessage, MessageBody, ConnectedSocket } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

@WebSocketGateway({ cors: { origin: '*' } })
export class ChatGateway {
  @WebSocketServer()
  server: Server;

  // Quand un utilisateur ouvre une discussion sur son téléphone
  @SubscribeMessage('joinRoom')
  handleJoinRoom(@ConnectedSocket() client: Socket, @MessageBody() conversationId: number) {
    // Le client rejoint un canal exclusif à cette conversation
    client.join(conversationId.toString()); 
    console.log(`Un utilisateur a rejoint la discussion ${conversationId}`);
  }

  // Fonction appelée par notre Controller pour diffuser un message
  broadcastNewMessage(conversationId: number, message: any) {
    // Envoie l'événement 'newMessage' uniquement aux gens dans ce salon
    this.server.to(conversationId.toString()).emit('newMessage', message);
  }
}
import { WebSocketGateway, WebSocketServer, SubscribeMessage, MessageBody, ConnectedSocket } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

@WebSocketGateway({ cors: { origin: '*' } })
export class ChatGateway {
  @WebSocketServer()
  server: Server;

  @SubscribeMessage('joinRoom')
  handleJoinRoom(@ConnectedSocket() client: Socket, @MessageBody() conversationId: number) {
    client.join(conversationId.toString()); 
    console.log(`Un utilisateur a rejoint la discussion ${conversationId}`);
  }

  broadcastNewMessage(conversationId: number, message: any) {
    this.server.to(conversationId.toString()).emit('newMessage', message);
  }
}
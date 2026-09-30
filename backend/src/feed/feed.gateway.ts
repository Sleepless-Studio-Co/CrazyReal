import { WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server } from 'socket.io';

@WebSocketGateway({ namespace: '/feed', cors: { origin: '*' } })
export class FeedGateway {
  @WebSocketServer()
  server: Server;

  broadcastNewPost() {
    this.server.emit('newPost');
  }
}

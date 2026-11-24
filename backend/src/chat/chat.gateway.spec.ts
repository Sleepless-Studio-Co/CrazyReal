import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { ChatGateway } from './chat.gateway';
import { ChatService } from './chat.service';

describe('ChatGateway', () => {
  let gateway: ChatGateway;
  let chatService: {
    getConversationIdsForUser: jest.Mock;
    isParticipant: jest.Mock;
  };
  let jwtService: { verifyAsync: jest.Mock };
  let configService: { getOrThrow: jest.Mock };
  let server: { to: jest.Mock; emit: jest.Mock };

  beforeEach(() => {
    chatService = {
      getConversationIdsForUser: jest.fn().mockResolvedValue([]),
      isParticipant: jest.fn(),
    };
    jwtService = { verifyAsync: jest.fn() };
    configService = { getOrThrow: jest.fn().mockReturnValue('secret') };
    server = {
      to: jest.fn().mockReturnValue({ emit: jest.fn() }),
      emit: jest.fn(),
    };

    gateway = new ChatGateway(
      chatService as unknown as ChatService,
      jwtService as unknown as JwtService,
      configService as unknown as ConfigService,
    );
    gateway.server = server as any;
  });

  const makeClient = (overrides: Record<string, unknown> = {}) => ({
    id: 's1',
    handshake: { headers: {}, auth: {} },
    data: {},
    disconnect: jest.fn(),
    join: jest.fn(),
    emit: jest.fn(),
    to: jest.fn().mockReturnValue({ emit: jest.fn() }),
    ...overrides,
  });

  describe('extractToken', () => {
    const extract = (client: any) => (gateway as any).extractToken(client);

    it('reads the token from the Authorization header', () => {
      expect(
        extract({
          handshake: { headers: { authorization: 'Bearer abc' }, auth: {} },
        }),
      ).toBe('abc');
    });

    it('falls back to the handshake auth token', () => {
      expect(
        extract({ handshake: { headers: {}, auth: { token: 'Bearer def' } } }),
      ).toBe('def');
    });

    it('returns null when nothing is provided', () => {
      expect(extract({ handshake: { headers: {}, auth: {} } })).toBeNull();
    });
  });

  describe('handleConnection', () => {
    it('disconnects when no token is supplied', async () => {
      const client = makeClient();
      await gateway.handleConnection(client as any);
      expect(client.disconnect).toHaveBeenCalled();
    });

    it('authenticates, stores the user and auto-joins their conversations', async () => {
      jwtService.verifyAsync.mockResolvedValue({
        sub: 1,
        email: 'a@b.com',
        username: 'alice',
      });
      chatService.getConversationIdsForUser.mockResolvedValue([10, 20]);
      const client = makeClient({
        handshake: { headers: {}, auth: { token: 'Bearer t' } },
      });

      await gateway.handleConnection(client as any);

      expect(client.data.user).toEqual({
        userId: 1,
        email: 'a@b.com',
        username: 'alice',
      });
      expect(client.join).toHaveBeenCalledWith('10');
      expect(client.join).toHaveBeenCalledWith('20');
    });

    it('disconnects when the token is invalid', async () => {
      jwtService.verifyAsync.mockRejectedValue(new Error('bad'));
      const client = makeClient({
        handshake: { headers: {}, auth: { token: 'Bearer t' } },
      });
      await gateway.handleConnection(client as any);
      expect(client.disconnect).toHaveBeenCalled();
    });
  });

  describe('handleJoinRoom', () => {
    it('rejects an unauthenticated client', async () => {
      const client = makeClient();
      await gateway.handleJoinRoom(client as any, 10);
      expect(client.emit).toHaveBeenCalledWith(
        'joinRoomError',
        'Non authentifié',
      );
    });

    it('rejects a non-participant', async () => {
      const client = makeClient({
        data: { user: { userId: 1, username: 'alice' } },
      });
      chatService.isParticipant.mockResolvedValue(false);
      await gateway.handleJoinRoom(client as any, 10);
      expect(client.emit).toHaveBeenCalledWith(
        'joinRoomError',
        'Accès refusé à cette conversation',
      );
    });

    it('joins the room for a participant', async () => {
      const client = makeClient({
        data: { user: { userId: 1, username: 'alice' } },
      });
      chatService.isParticipant.mockResolvedValue(true);
      await gateway.handleJoinRoom(client as any, 10);
      expect(client.join).toHaveBeenCalledWith('10');
      expect(client.emit).toHaveBeenCalledWith('joinRoomSuccess', {
        conversationId: 10,
      });
    });
  });

  describe('typing indicators', () => {
    it('ignores unauthenticated typing events', async () => {
      const client = makeClient();
      await gateway.handleTyping(client as any, 10);
      expect(chatService.isParticipant).not.toHaveBeenCalled();
    });

    it('emits userTyping to other participants', async () => {
      const client = makeClient({
        data: { user: { userId: 1, username: 'alice' } },
      });
      chatService.isParticipant.mockResolvedValue(true);

      await gateway.handleTyping(client as any, 10);
      expect(client.to).toHaveBeenCalledWith('10');
    });

    it('emits userStoppedTyping to other participants', async () => {
      const client = makeClient({
        data: { user: { userId: 1, username: 'alice' } },
      });
      chatService.isParticipant.mockResolvedValue(true);

      await gateway.handleStopTyping(client as any, 10);
      expect(client.to).toHaveBeenCalledWith('10');
    });
  });

  describe('broadcastNewMessage', () => {
    it('emits newMessage to the conversation room', () => {
      gateway.broadcastNewMessage(10, { id: 5 });
      expect(server.to).toHaveBeenCalledWith('10');
    });
  });
});

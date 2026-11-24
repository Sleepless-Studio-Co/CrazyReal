import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { NotificationGateway } from './notification.gateway';
import { PrismaService } from '../prisma/prisma.service';

describe('NotificationGateway', () => {
  let gateway: NotificationGateway;
  let jwtService: { verifyAsync: jest.Mock };
  let configService: { getOrThrow: jest.Mock };
  let prisma: { challenge: { findMany: jest.Mock } };
  let server: { to: jest.Mock; emit: jest.Mock };

  beforeEach(() => {
    jwtService = { verifyAsync: jest.fn() };
    configService = { getOrThrow: jest.fn().mockReturnValue('secret') };
    prisma = { challenge: { findMany: jest.fn().mockResolvedValue([]) } };
    server = {
      to: jest.fn().mockReturnValue({ emit: jest.fn() }),
      emit: jest.fn(),
    };

    gateway = new NotificationGateway(
      jwtService as unknown as JwtService,
      configService as unknown as ConfigService,
      prisma as unknown as PrismaService,
    );
    gateway.server = server as any;
  });

  describe('extractToken', () => {
    const extract = (client: any) => (gateway as any).extractToken(client);

    it('returns the raw token when no Bearer prefix is present', () => {
      expect(extract({ handshake: { auth: { token: 'abc' } } })).toBe('abc');
    });

    it('strips the Bearer prefix', () => {
      expect(extract({ handshake: { auth: { token: 'Bearer abc' } } })).toBe(
        'abc',
      );
    });

    it('returns null when no token is provided', () => {
      expect(extract({ handshake: { auth: {} } })).toBeNull();
    });
  });

  describe('handleConnection', () => {
    it('disconnects when no token is supplied', async () => {
      const client = {
        id: 's1',
        handshake: { auth: {} },
        disconnect: jest.fn(),
      };
      await gateway.handleConnection(client as any);
      expect(client.disconnect).toHaveBeenCalled();
    });

    it('registers the socket for a valid token', async () => {
      jwtService.verifyAsync.mockResolvedValue({ sub: 42 });
      const client = {
        id: 's1',
        handshake: { auth: { token: 'Bearer t' } },
        disconnect: jest.fn(),
      };

      await gateway.handleConnection(client as any);

      expect(jwtService.verifyAsync).toHaveBeenCalledWith('t', {
        secret: 'secret',
      });
      expect((gateway as any).userSockets.get(42)).toEqual(['s1']);
      expect(client.disconnect).not.toHaveBeenCalled();
    });

    it('disconnects when the token is invalid', async () => {
      jwtService.verifyAsync.mockRejectedValue(new Error('bad token'));
      const client = {
        id: 's1',
        handshake: { auth: { token: 'Bearer t' } },
        disconnect: jest.fn(),
      };

      await gateway.handleConnection(client as any);

      expect(client.disconnect).toHaveBeenCalled();
    });
  });

  describe('handleDisconnect', () => {
    it('removes the socket id and cleans up empty entries', () => {
      (gateway as any).userSockets.set(1, ['s1', 's2']);
      gateway.handleDisconnect({ id: 's1' } as any);
      expect((gateway as any).userSockets.get(1)).toEqual(['s2']);

      gateway.handleDisconnect({ id: 's2' } as any);
      expect((gateway as any).userSockets.has(1)).toBe(false);
    });
  });

  describe('sendToUser / sendToUsers / broadcast', () => {
    it('emits to every socket of the user', () => {
      (gateway as any).userSockets.set(1, ['s1', 's2']);
      gateway.sendToUser(1, 'event', { a: 1 });

      expect(server.to).toHaveBeenCalledWith('s1');
      expect(server.to).toHaveBeenCalledWith('s2');
    });

    it('broadcasts to the whole namespace', () => {
      gateway.broadcast('event', { a: 1 });
      expect(server.emit).toHaveBeenCalledWith('event', { a: 1 });
    });

    it('sends to each user id in the list', async () => {
      const sendToUser = jest
        .spyOn(gateway, 'sendToUser')
        .mockImplementation(() => {});
      await gateway.sendToUsers([1, 2], 'event', {});
      expect(sendToUser).toHaveBeenCalledTimes(2);
    });
  });
});

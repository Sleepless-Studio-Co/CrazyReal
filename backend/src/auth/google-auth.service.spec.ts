import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { LoginTicket } from 'google-auth-library';
import { GoogleAuthService } from './google-auth.service';

interface ClientStub {
  client: { verifyIdToken: jest.Mock };
}

describe('GoogleAuthService', () => {
  const configServiceMock = {
    get: jest.fn(),
  };

  const buildService = () =>
    new GoogleAuthService(configServiceMock as unknown as ConfigService);

  const stubClient = (
    service: GoogleAuthService,
    verifyIdToken: jest.Mock,
  ): ClientStub => {
    const stub: ClientStub = { client: { verifyIdToken } };
    (service as unknown as ClientStub).client = stub.client;
    return stub;
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('rejects when GOOGLE_CLIENT_ID is not configured', async () => {
    configServiceMock.get.mockReturnValue(undefined);
    const service = buildService();

    await expect(service.verify('token')).rejects.toThrow(UnauthorizedException);
  });

  it('returns a normalized profile for a valid token', async () => {
    configServiceMock.get.mockReturnValue('web-client-id, ios-client-id');
    const service = buildService();
    const verifyIdToken = jest.fn().mockResolvedValue({
      getPayload: () => ({
        sub: '123',
        email: 'USER@Example.com',
        email_verified: true,
        name: 'User',
        picture: 'https://example.com/pic.png',
      }),
    } as unknown as LoginTicket);
    stubClient(service, verifyIdToken);

    const profile = await service.verify('token');

    expect(profile).toEqual({
      googleId: '123',
      email: 'user@example.com',
      emailVerified: true,
      name: 'User',
      picture: 'https://example.com/pic.png',
    });
    expect(verifyIdToken).toHaveBeenCalledWith({
      idToken: 'token',
      audience: ['web-client-id', 'ios-client-id'],
    });
  });

  it('maps verification failures to UnauthorizedException', async () => {
    configServiceMock.get.mockReturnValue('web-client-id');
    const service = buildService();
    stubClient(service, jest.fn().mockRejectedValue(new Error('bad signature')));

    await expect(service.verify('token')).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('rejects tokens missing required claims', async () => {
    configServiceMock.get.mockReturnValue('web-client-id');
    const service = buildService();
    stubClient(
      service,
      jest.fn().mockResolvedValue({
        getPayload: () => ({ sub: '123' }),
      } as unknown as LoginTicket),
    );

    await expect(service.verify('token')).rejects.toThrow(
      UnauthorizedException,
    );
  });
});

import { ConfigService } from '@nestjs/config';
import { JwtStrategy } from './jwt.strategy';

describe('JwtStrategy', () => {
  const configService = {
    getOrThrow: jest.fn().mockReturnValue('test-secret'),
  } as unknown as ConfigService;

  it('builds a ValidatedUser from the JWT payload', async () => {
    const strategy = new JwtStrategy(configService);

    await expect(
      strategy.validate({
        sub: 7,
        email: 'a@b.com',
        username: 'alice',
      }),
    ).resolves.toEqual({
      userId: 7,
      email: 'a@b.com',
      username: 'alice',
    });
  });
});

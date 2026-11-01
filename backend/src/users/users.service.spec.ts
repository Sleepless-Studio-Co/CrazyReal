import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from './users.service';

describe('UsersService', () => {
  const prismaServiceMock = {
    user: {
      findFirst: jest.fn(),
    },
  };

  const service = new UsersService(
    prismaServiceMock as unknown as PrismaService,
  );

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findByEmail', () => {
    it('matches emails case-insensitively so Google accounts can be linked', async () => {
      const user = {
        id: 1,
        email: 'User@Example.com',
        username: 'user',
        avatarUrl: null,
        avatarKey: null,
        isPrivate: false,
        emailVerified: true,
        createdAt: new Date('2026-01-01'),
      };
      prismaServiceMock.user.findFirst.mockResolvedValue(user);

      await expect(service.findByEmail('user@example.com')).resolves.toBe(user);

      expect(prismaServiceMock.user.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            email: { equals: 'user@example.com', mode: 'insensitive' },
          },
        }),
      );
    });
  });
});

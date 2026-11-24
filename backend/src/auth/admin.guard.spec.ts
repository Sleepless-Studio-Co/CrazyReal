import { ExecutionContext } from '@nestjs/common';
import { Role } from '@prisma/client';
import { Test, TestingModule } from '@nestjs/testing';
import { AdminGuard } from './admin.guard';
import { PrismaService } from '../prisma/prisma.service';

describe('AdminGuard', () => {
  let guard: AdminGuard;
  let prismaService: { user: { findUnique: jest.Mock } };

  const contextWithUser = (user?: { userId?: number }) => {
    const context = {
      switchToHttp: () => ({
        getRequest: () => ({ user }),
      }),
    } as unknown as ExecutionContext;
    return context;
  };

  beforeEach(async () => {
    prismaService = { user: { findUnique: jest.fn() } };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AdminGuard,
        { provide: PrismaService, useValue: prismaService },
      ],
    }).compile();

    guard = module.get<AdminGuard>(AdminGuard);
  });

  it('denies a request without a user', async () => {
    await expect(guard.canActivate(contextWithUser(undefined))).resolves.toBe(
      false,
    );
    expect(prismaService.user.findUnique).not.toHaveBeenCalled();
  });

  it('denies a request without a userId', async () => {
    await expect(guard.canActivate(contextWithUser({}))).resolves.toBe(false);
  });

  it('grants access to an admin user', async () => {
    prismaService.user.findUnique.mockResolvedValue({
      id: 1,
      role: Role.ADMIN,
    });
    await expect(
      guard.canActivate(contextWithUser({ userId: 1 })),
    ).resolves.toBe(true);
  });

  it('denies a non-admin user', async () => {
    prismaService.user.findUnique.mockResolvedValue({ id: 1, role: Role.USER });
    await expect(
      guard.canActivate(contextWithUser({ userId: 1 })),
    ).resolves.toBe(false);
  });

  it('denies when the user no longer exists', async () => {
    prismaService.user.findUnique.mockResolvedValue(null);
    await expect(
      guard.canActivate(contextWithUser({ userId: 1 })),
    ).resolves.toBe(false);
  });
});

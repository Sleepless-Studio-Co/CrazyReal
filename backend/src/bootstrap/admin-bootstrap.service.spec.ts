import { Test, TestingModule } from '@nestjs/testing';
import { AdminBootstrapService } from './admin-bootstrap.service';
import { PrismaService } from '../prisma/prisma.service';

describe('AdminBootstrapService', () => {
  let service: AdminBootstrapService;
  let prismaService: {
    user: { findUnique: jest.Mock; create: jest.Mock; update: jest.Mock };
  };

  const envKeys = [
    'BOOTSTRAP_ADMIN',
    'BOOTSTRAP_ADMIN_EMAIL',
    'BOOTSTRAP_ADMIN_PASSWORD',
    'BOOTSTRAP_ADMIN_USERNAME',
  ] as const;
  const originalEnv: Record<string, string | undefined> = {};

  beforeEach(async () => {
    for (const key of envKeys) {
      originalEnv[key] = process.env[key];
      delete process.env[key];
    }

    prismaService = {
      user: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn() },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AdminBootstrapService,
        { provide: PrismaService, useValue: prismaService },
      ],
    }).compile();

    service = module.get<AdminBootstrapService>(AdminBootstrapService);
  });

  afterEach(() => {
    for (const key of envKeys) {
      if (originalEnv[key] === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = originalEnv[key];
      }
    }
  });

  it('does nothing when BOOTSTRAP_ADMIN is not "true"', async () => {
    await service.createDefaultUser();
    expect(prismaService.user.findUnique).not.toHaveBeenCalled();
  });

  it('throws when credentials are missing', async () => {
    process.env.BOOTSTRAP_ADMIN = 'true';
    await expect(service.createDefaultUser()).rejects.toThrow(
      'BOOTSTRAP_ADMIN=true requires',
    );
  });

  it('creates an admin account when none exists', async () => {
    process.env.BOOTSTRAP_ADMIN = 'true';
    process.env.BOOTSTRAP_ADMIN_EMAIL = 'admin@example.com';
    process.env.BOOTSTRAP_ADMIN_PASSWORD = 'pass';
    prismaService.user.findUnique.mockResolvedValue(null);
    prismaService.user.create.mockResolvedValue({ id: 1 });

    await service.createDefaultUser();

    expect(prismaService.user.create).toHaveBeenCalledWith({
      data: {
        email: 'admin@example.com',
        password: expect.any(String),
        username: 'admin',
        role: 'ADMIN',
      },
    });
  });

  it('promotes an existing non-admin user', async () => {
    process.env.BOOTSTRAP_ADMIN = 'true';
    process.env.BOOTSTRAP_ADMIN_EMAIL = 'admin@example.com';
    process.env.BOOTSTRAP_ADMIN_PASSWORD = 'pass';
    prismaService.user.findUnique.mockResolvedValue({ id: 1, role: 'USER' });
    prismaService.user.update.mockResolvedValue({ id: 1, role: 'ADMIN' });

    await service.createDefaultUser();

    expect(prismaService.user.update).toHaveBeenCalledWith({
      where: { email: 'admin@example.com' },
      data: { role: 'ADMIN' },
    });
    expect(prismaService.user.create).not.toHaveBeenCalled();
  });

  it('leaves an existing admin untouched', async () => {
    process.env.BOOTSTRAP_ADMIN = 'true';
    process.env.BOOTSTRAP_ADMIN_EMAIL = 'admin@example.com';
    process.env.BOOTSTRAP_ADMIN_PASSWORD = 'pass';
    prismaService.user.findUnique.mockResolvedValue({ id: 1, role: 'ADMIN' });

    await service.createDefaultUser();

    expect(prismaService.user.update).not.toHaveBeenCalled();
    expect(prismaService.user.create).not.toHaveBeenCalled();
  });
});

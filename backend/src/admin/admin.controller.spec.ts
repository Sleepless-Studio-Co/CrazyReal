import { Test, TestingModule } from '@nestjs/testing';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/admin.guard';

describe('AdminController', () => {
  let controller: AdminController;
  let adminService: {
    importChallengesFromFile: jest.Mock;
    listChallenges: jest.Mock;
    createChallenge: jest.Mock;
    updateChallenge: jest.Mock;
    deleteChallenge: jest.Mock;
  };

  beforeEach(async () => {
    adminService = {
      importChallengesFromFile: jest.fn(),
      listChallenges: jest.fn(),
      createChallenge: jest.fn(),
      updateChallenge: jest.fn(),
      deleteChallenge: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AdminController],
      providers: [{ provide: AdminService, useValue: adminService }],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: jest.fn(() => true) })
      .overrideGuard(AdminGuard)
      .useValue({ canActivate: jest.fn(() => true) })
      .compile();

    controller = module.get<AdminController>(AdminController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('delegates importChallenges', async () => {
    adminService.importChallengesFromFile.mockResolvedValue({ imported: 1 });
    await expect(controller.importChallenges()).resolves.toEqual({
      imported: 1,
    });
  });

  it('delegates listChallenges', async () => {
    adminService.listChallenges.mockResolvedValue([]);
    await expect(controller.listChallenges()).resolves.toEqual([]);
  });

  it('delegates createChallenge', async () => {
    adminService.createChallenge.mockResolvedValue({ id: 1 });
    await expect(
      controller.createChallenge({ title: 'X' } as any),
    ).resolves.toEqual({
      id: 1,
    });
  });

  it('delegates updateChallenge', async () => {
    adminService.updateChallenge.mockResolvedValue({ id: 1 });
    await controller.updateChallenge(1, {} as any);
    expect(adminService.updateChallenge).toHaveBeenCalledWith(1, {});
  });

  it('delegates deleteChallenge', async () => {
    adminService.deleteChallenge.mockResolvedValue({ deleted: true });
    await expect(controller.deleteChallenge(1)).resolves.toEqual({
      deleted: true,
    });
  });
});

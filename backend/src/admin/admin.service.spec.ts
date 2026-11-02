import { ConflictException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Test, TestingModule } from '@nestjs/testing';
import { AdminService } from './admin.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationGateway } from '../bootstrap/notification.gateway';
import * as fs from 'fs';

jest.mock('fs', () => {
  const actual = jest.requireActual('fs');
  return {
    ...actual,
    existsSync: jest.fn((...args: any[]) => actual.existsSync(...args)),
    readFileSync: jest.fn((...args: any[]) => actual.readFileSync(...args)),
  };
});

const mockedExistsSync = fs.existsSync as jest.Mock;
const mockedReadFileSync = fs.readFileSync as jest.Mock;

describe('AdminService', () => {
  let service: AdminService;
  let prismaService: {
    challenge: {
      findMany: jest.Mock;
      create: jest.Mock;
      createMany: jest.Mock;
      update: jest.Mock;
      delete: jest.Mock;
      findUnique: jest.Mock;
    };
    post: { count: jest.Mock };
  };
  let notificationGateway: { broadcast: jest.Mock };

  beforeEach(async () => {
    jest.clearAllMocks();

    prismaService = {
      challenge: {
        findMany: jest.fn(),
        create: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
        findUnique: jest.fn(),
      },
      post: { count: jest.fn() },
    };
    notificationGateway = { broadcast: jest.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AdminService,
        { provide: PrismaService, useValue: prismaService },
        { provide: NotificationGateway, useValue: notificationGateway },
      ],
    }).compile();

    service = module.get<AdminService>(AdminService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('listChallenges', () => {
    it('lists global challenges ordered by date desc with post count', async () => {
      prismaService.challenge.findMany.mockResolvedValue([{ id: 1 }]);
      await expect(service.listChallenges()).resolves.toEqual([{ id: 1 }]);
      expect(prismaService.challenge.findMany).toHaveBeenCalledWith({
        where: { conversationId: null },
        orderBy: { date: 'desc' },
        include: { _count: { select: { posts: true } } },
      });
    });
  });

  describe('createChallenge', () => {
    it('creates a challenge and broadcasts the event', async () => {
      prismaService.challenge.create.mockResolvedValue({
        id: 1,
        title: 'Défi',
      });
      await expect(
        service.createChallenge({ title: 'Défi', type: 'WEEKLY_A' }),
      ).resolves.toEqual({ id: 1, title: 'Défi' });

      expect(prismaService.challenge.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          title: 'Défi',
          type: 'WEEKLY_A',
          isActive: true,
        }),
      });
      expect(notificationGateway.broadcast).toHaveBeenCalledWith(
        'challengeCreated',
        expect.objectContaining({ isGlobal: true }),
      );
    });

    it('maps a P2002 to a ConflictException', async () => {
      prismaService.challenge.create.mockRejectedValue(
        new Prisma.PrismaClientKnownRequestError('dup', {
          code: 'P2002',
          clientVersion: 'test',
        }),
      );
      await expect(
        service.createChallenge({ title: 'Défi' }),
      ).rejects.toBeInstanceOf(ConflictException);
    });
  });

  describe('updateChallenge', () => {
    it('throws NotFoundException when the challenge does not exist', async () => {
      prismaService.challenge.findUnique.mockResolvedValue(null);
      await expect(service.updateChallenge(1, {})).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('throws ConflictException for a group challenge', async () => {
      prismaService.challenge.findUnique.mockResolvedValue({
        id: 1,
        conversationId: 5,
      });
      await expect(service.updateChallenge(1, {})).rejects.toBeInstanceOf(
        ConflictException,
      );
    });

    it('updates only the provided fields', async () => {
      prismaService.challenge.findUnique.mockResolvedValue({
        id: 1,
        conversationId: null,
      });
      prismaService.challenge.update.mockResolvedValue({ id: 1, title: 'New' });

      await service.updateChallenge(1, { title: 'New', isActive: false });

      expect(prismaService.challenge.update).toHaveBeenCalledWith({
        where: { id: 1 },
        data: { title: 'New', isActive: false },
      });
    });
  });

  describe('deleteChallenge', () => {
    it('throws NotFoundException when the challenge does not exist', async () => {
      prismaService.challenge.findUnique.mockResolvedValue(null);
      await expect(service.deleteChallenge(1)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('refuses to delete a challenge that still has posts', async () => {
      prismaService.challenge.findUnique.mockResolvedValue({
        id: 1,
        conversationId: null,
      });
      prismaService.post.count.mockResolvedValue(2);
      await expect(service.deleteChallenge(1)).rejects.toBeInstanceOf(
        ConflictException,
      );
      expect(prismaService.challenge.delete).not.toHaveBeenCalled();
    });

    it('deletes an empty global challenge', async () => {
      prismaService.challenge.findUnique.mockResolvedValue({
        id: 1,
        conversationId: null,
      });
      prismaService.post.count.mockResolvedValue(0);
      prismaService.challenge.delete.mockResolvedValue({ id: 1 });

      await expect(service.deleteChallenge(1)).resolves.toEqual({
        deleted: true,
      });
      expect(prismaService.challenge.delete).toHaveBeenCalledWith({
        where: { id: 1 },
      });
    });
  });

  describe('importChallengesFromFile', () => {
    it('throws NotFoundException when the file is missing', async () => {
      mockedExistsSync.mockReturnValue(false);
      await expect(service.importChallengesFromFile()).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('imports nothing for an empty list', async () => {
      mockedExistsSync.mockReturnValue(true);
      mockedReadFileSync.mockReturnValue('[]');
      await expect(service.importChallengesFromFile()).resolves.toEqual({
        imported: 0,
      });
      expect(prismaService.challenge.createMany).not.toHaveBeenCalled();
    });

    it('imports the parsed challenges with defaults', async () => {
      mockedExistsSync.mockReturnValue(true);
      mockedReadFileSync.mockReturnValue(
        JSON.stringify([{ title: 'A', type: 'SPECIAL' }]),
      );
      prismaService.challenge.createMany.mockResolvedValue({ count: 1 });

      await expect(service.importChallengesFromFile()).resolves.toEqual({
        imported: 1,
      });
      expect(prismaService.challenge.createMany).toHaveBeenCalledWith({
        data: [
          expect.objectContaining({
            title: 'A',
            type: 'SPECIAL',
            isActive: true,
          }),
        ],
        skipDuplicates: true,
      });
    });
  });
});

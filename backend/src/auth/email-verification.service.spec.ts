import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { EmailVerificationService } from './email-verification.service';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';
import { ConfigService } from '@nestjs/config';

describe('EmailVerificationService', () => {
  let service: EmailVerificationService;

  const prismaMock = {
    emailVerificationToken: {
      create: jest.fn(),
      deleteMany: jest.fn(),
      delete: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
    },
    user: {
      update: jest.fn(),
      findUnique: jest.fn(),
    },
    $transaction: jest.fn(),
  };

  const mailMock = { send: jest.fn() };
  const configMock = {
    get: jest.fn().mockReturnValue('http://localhost:3000'),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    prismaMock.$transaction.mockResolvedValue([]);
    prismaMock.emailVerificationToken.create.mockResolvedValue({});
    prismaMock.emailVerificationToken.deleteMany.mockResolvedValue({});
    mailMock.send.mockResolvedValue(undefined);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        EmailVerificationService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: MailService, useValue: mailMock },
        { provide: ConfigService, useValue: configMock },
      ],
    }).compile();

    service = module.get(EmailVerificationService);
  });

  describe('createAndSend', () => {
    it('issues a token and sends an email', async () => {
      await service.createAndSend({ id: 1, email: 'a@b.com', username: 'amy' });

      expect(prismaMock.$transaction).toHaveBeenCalled();
      expect(mailMock.send).toHaveBeenCalledWith(
        expect.objectContaining({ to: 'a@b.com' }),
      );
    });

    it('does not throw when the email fails to send', async () => {
      mailMock.send.mockRejectedValueOnce(new Error('smtp down'));
      await expect(
        service.createAndSend({ id: 1, email: 'a@b.com', username: 'amy' }),
      ).resolves.toBeUndefined();
    });
  });

  describe('verify', () => {
    it('rejects an unknown token', async () => {
      prismaMock.emailVerificationToken.findUnique.mockResolvedValue(null);
      await expect(service.verify('nope')).rejects.toThrow(BadRequestException);
    });

    it('rejects (and deletes) an expired token', async () => {
      prismaMock.emailVerificationToken.findUnique.mockResolvedValue({
        id: 5,
        userId: 1,
        expiresAt: new Date(Date.now() - 1000),
        user: { email: 'a@b.com' },
      });

      await expect(service.verify('expired')).rejects.toThrow(BadRequestException);
      expect(prismaMock.emailVerificationToken.delete).toHaveBeenCalledWith({
        where: { id: 5 },
      });
    });

    it('marks the user verified for a valid token', async () => {
      prismaMock.emailVerificationToken.findUnique.mockResolvedValue({
        id: 5,
        userId: 1,
        expiresAt: new Date(Date.now() + 100000),
        user: { email: 'a@b.com' },
      });

      const result = await service.verify('valid');

      expect(result).toEqual({ email: 'a@b.com' });
      expect(prismaMock.$transaction).toHaveBeenCalled();
    });
  });

  describe('resendForUser', () => {
    it('throws when the user does not exist', async () => {
      prismaMock.user.findUnique.mockResolvedValue(null);
      await expect(service.resendForUser(1)).rejects.toThrow(NotFoundException);
    });

    it('throws when the email is already verified', async () => {
      prismaMock.user.findUnique.mockResolvedValue({
        id: 1,
        email: 'a@b.com',
        username: 'amy',
        emailVerified: true,
      });
      await expect(service.resendForUser(1)).rejects.toThrow(BadRequestException);
    });

    it('throws when a token was issued too recently (cooldown)', async () => {
      prismaMock.user.findUnique.mockResolvedValue({
        id: 1,
        email: 'a@b.com',
        username: 'amy',
        emailVerified: false,
      });
      prismaMock.emailVerificationToken.findFirst.mockResolvedValue({
        createdAt: new Date(),
      });
      await expect(service.resendForUser(1)).rejects.toThrow(BadRequestException);
    });

    it('resends when allowed', async () => {
      prismaMock.user.findUnique.mockResolvedValue({
        id: 1,
        email: 'a@b.com',
        username: 'amy',
        emailVerified: false,
      });
      prismaMock.emailVerificationToken.findFirst.mockResolvedValue(null);

      await service.resendForUser(1);

      expect(mailMock.send).toHaveBeenCalled();
    });
  });
});

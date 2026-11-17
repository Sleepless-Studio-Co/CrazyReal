import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { NotificationGateway } from '../bootstrap/notification.gateway';
import { PrismaService } from '../prisma/prisma.service';
import { ChallengeTranslationService } from '../translation/challenge-translation.service';
import { AdminService } from './admin.service';

describe('AdminService (traductions)', () => {
  const existing = {
    id: 1,
    title: 'Selfie',
    description: 'Au soleil',
    conversationId: null,
    translations: {
      en: { title: 'Selfie', description: 'In the sun' },
      es: { title: 'Selfi', description: 'Al sol', manual: true },
    },
  };

  let prisma: { challenge: { findUnique: jest.Mock; create: jest.Mock; update: jest.Mock } };
  let gateway: { broadcast: jest.Mock };
  let translation: { buildTranslations: jest.Mock; translateOne: jest.Mock };
  let service: AdminService;

  beforeEach(() => {
    prisma = {
      challenge: {
        findUnique: jest.fn().mockResolvedValue(existing),
        create: jest.fn(async ({ data }) => ({ id: 1, ...data })),
        update: jest.fn(async ({ data }) => ({ ...existing, ...data })),
      },
    };
    gateway = { broadcast: jest.fn() };
    translation = {
      buildTranslations: jest.fn().mockResolvedValue({ en: { title: 'T', description: '' } }),
      translateOne: jest.fn().mockResolvedValue({ title: 'Auto', description: 'auto' }),
    };
    service = new AdminService(
      prisma as unknown as PrismaService,
      gateway as unknown as NotificationGateway,
      translation as unknown as ChallengeTranslationService,
    );
  });

  describe('createChallenge', () => {
    it('should store the translations and send them with the notification', async () => {
      await service.createChallenge({ title: ' Selfie ', description: '' } as never);

      expect(translation.buildTranslations).toHaveBeenCalledWith('Selfie', '');
      expect(prisma.challenge.create.mock.calls[0][0].data.translations).toEqual({
        en: { title: 'T', description: '' },
      });
      expect(gateway.broadcast).toHaveBeenCalledWith(
        'challengeCreated',
        expect.objectContaining({
          challengeTranslations: { en: { title: 'T', description: '' } },
        }),
      );
    });

    it('should store SQL NULL when nothing could be translated', async () => {
      translation.buildTranslations.mockResolvedValue(null);

      await service.createChallenge({ title: 'Selfie' } as never);

      expect(prisma.challenge.create.mock.calls[0][0].data.translations).toBe(Prisma.DbNull);
    });
  });

  describe('updateChallenge', () => {
    it('should retranslate when the French text changes, keeping manual ones', async () => {
      await service.updateChallenge(1, { title: 'Nouveau' });

      expect(translation.buildTranslations).toHaveBeenCalledWith(
        'Nouveau',
        'Au soleil',
        existing.translations,
      );
    });

    it('should not call DeepL when only other fields change', async () => {
      await service.updateChallenge(1, { isActive: false, title: 'Selfie' });

      expect(translation.buildTranslations).not.toHaveBeenCalled();
      expect(prisma.challenge.update.mock.calls[0][0].data).not.toHaveProperty('translations');
    });
  });

  describe('setManualTranslation', () => {
    it('should save the translation as manual without touching the others', async () => {
      await service.setManualTranslation(1, 'en', { title: ' Sunny selfie ', description: 'Sun' });

      expect(prisma.challenge.update.mock.calls[0][0].data.translations).toEqual({
        en: { title: 'Sunny selfie', description: 'Sun', manual: true },
        es: existing.translations.es,
      });
    });

    it('should reject an unknown locale', async () => {
      await expect(
        service.setManualTranslation(1, 'it', { title: 'Ciao' }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(prisma.challenge.update).not.toHaveBeenCalled();
    });
  });

  describe('resetTranslation', () => {
    it('should replace a manual translation by a fresh DeepL one', async () => {
      await service.resetTranslation(1, 'es');

      expect(translation.translateOne).toHaveBeenCalledWith('Selfie', 'Au soleil', 'es');
      expect(prisma.challenge.update.mock.calls[0][0].data.translations).toEqual({
        en: existing.translations.en,
        es: { title: 'Auto', description: 'auto' },
      });
    });

    it('should fall back to French when DeepL fails', async () => {
      translation.translateOne.mockResolvedValue(null);

      await service.resetTranslation(1, 'es');

      expect(prisma.challenge.update.mock.calls[0][0].data.translations).toEqual({
        en: existing.translations.en,
      });
    });
  });
});

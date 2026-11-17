import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ChallengeTranslationService } from './challenge-translation.service';
import { DeepLService } from './deepl.service';

describe('ChallengeTranslationService', () => {
  let deepl: { isConfigured: boolean; translate: jest.Mock };
  let prisma: { challenge: { findMany: jest.Mock; update: jest.Mock } };
  let service: ChallengeTranslationService;

  beforeEach(() => {
    deepl = {
      isConfigured: true,
      // Simule DeepL : préfixe chaque texte par la langue cible.
      translate: jest.fn(async (texts: string[], lang: string) =>
        texts.map((t) => `[${lang}] ${t}`),
      ),
    };
    prisma = { challenge: { findMany: jest.fn(), update: jest.fn() } };
    service = new ChallengeTranslationService(
      prisma as unknown as PrismaService,
      deepl as unknown as DeepLService,
    );
  });

  describe('buildTranslations', () => {
    it('should translate title and description into every locale', async () => {
      const result = await service.buildTranslations('Selfie', 'Au soleil');

      expect(result).toEqual({
        en: { title: '[EN-US] Selfie', description: '[EN-US] Au soleil' },
        es: { title: '[ES] Selfie', description: '[ES] Au soleil' },
        pt: { title: '[PT-BR] Selfie', description: '[PT-BR] Au soleil' },
        de: { title: '[DE] Selfie', description: '[DE] Au soleil' },
      });
    });

    it('should not send an empty description to DeepL', async () => {
      const result = await service.buildTranslations('Selfie', '');

      expect(deepl.translate).toHaveBeenCalledWith(['Selfie'], 'EN-US');
      expect(result?.en).toEqual({ title: '[EN-US] Selfie', description: '' });
    });

    it('should keep manual translations untouched', async () => {
      const manual = { title: 'Hand made', description: 'By an admin', manual: true };

      const result = await service.buildTranslations('Selfie', 'Au soleil', {
        en: manual,
        es: { title: 'vieja', description: 'vieja' },
      });

      expect(result?.en).toBe(manual);
      expect(result?.es?.title).toBe('[ES] Selfie');
      expect(deepl.translate).not.toHaveBeenCalledWith(expect.anything(), 'EN-US');
    });

    it('should drop a locale whose translation failed', async () => {
      deepl.translate.mockImplementation(async (texts: string[], lang: string) =>
        lang === 'DE' ? null : texts,
      );

      const result = await service.buildTranslations('Selfie', '');

      expect(result).not.toHaveProperty('de');
      expect(result).toHaveProperty('en');
    });

    it('should return null when DeepL is unavailable', async () => {
      deepl.translate.mockResolvedValue(null);

      await expect(service.buildTranslations('Selfie', '')).resolves.toBeNull();
    });
  });

  describe('translateMissing', () => {
    it('should translate global challenges without translations', async () => {
      prisma.challenge.findMany.mockResolvedValue([
        { id: 1, title: 'A', description: '' },
        { id: 2, title: 'B', description: 'b' },
      ]);

      await expect(service.translateMissing()).resolves.toBe(2);

      expect(prisma.challenge.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { conversationId: null, translations: { equals: Prisma.DbNull } },
        }),
      );
      expect(prisma.challenge.update).toHaveBeenCalledTimes(2);
      expect(prisma.challenge.update.mock.calls[1][0]).toMatchObject({
        where: { id: 2 },
        data: { translations: { en: { title: '[EN-US] B', description: '[EN-US] b' } } },
      });
    });

    it('should do nothing without an API key', async () => {
      deepl.isConfigured = false;

      await expect(service.translateMissing()).resolves.toBe(0);
      expect(prisma.challenge.findMany).not.toHaveBeenCalled();
    });
  });
});

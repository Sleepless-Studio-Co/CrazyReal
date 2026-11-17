import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { DeepLService } from './deepl.service';
import {
  CHALLENGE_LOCALES,
  ChallengeLocale,
  ChallengeTranslations,
} from './translation.constants';

/** Valeur à écrire dans la colonne JSON `translations` (DbNull = SQL NULL). */
export function toTranslationsColumn(
  translations: ChallengeTranslations | null,
): Prisma.InputJsonValue | typeof Prisma.DbNull {
  return translations
    ? (translations as Prisma.InputJsonValue)
    : Prisma.DbNull;
}

@Injectable()
export class ChallengeTranslationService {
  private readonly logger = new Logger(ChallengeTranslationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly deepl: DeepLService,
  ) {}

  /**
   * Traduit un titre et une description français dans toutes les langues de
   * CHALLENGE_LOCALES. Les traductions `manual` de `existing` sont conservées.
   * Une langue dont la traduction échoue est simplement absente : l'app
   * retombe alors sur le français, plutôt que d'afficher une traduction
   * périmée. Renvoie `null` si aucune langue n'est disponible.
   */
  async buildTranslations(
    title: string,
    description: string,
    existing?: ChallengeTranslations | null,
  ): Promise<ChallengeTranslations | null> {
    const texts = description ? [title, description] : [title];
    const result: ChallengeTranslations = {};

    await Promise.all(
      (Object.keys(CHALLENGE_LOCALES) as ChallengeLocale[]).map(
        async (locale) => {
          const previous = existing?.[locale];
          if (previous?.manual) {
            result[locale] = previous;
            return;
          }

          const translated = await this.deepl.translate(
            texts,
            CHALLENGE_LOCALES[locale],
          );
          if (translated) {
            result[locale] = {
              title: translated[0],
              description: description ? translated[1] : '',
            };
          }
        },
      ),
    );

    return Object.keys(result).length > 0 ? result : null;
  }

  /**
   * Traduit les défis globaux qui n'ont encore aucune traduction (défis créés
   * avant cette fonctionnalité, import JSON…). Renvoie le nombre traduit.
   */
  async translateMissing(): Promise<number> {
    if (!this.deepl.isConfigured) return 0;

    const challenges = await this.prisma.challenge.findMany({
      where: { conversationId: null, translations: { equals: Prisma.DbNull } },
      select: { id: true, title: true, description: true },
      orderBy: { id: 'asc' },
    });

    let translatedCount = 0;
    // Séquentiel pour rester loin des limites de débit de DeepL.
    for (const challenge of challenges) {
      const translations = await this.buildTranslations(
        challenge.title,
        challenge.description,
      );
      if (!translations) continue;

      await this.prisma.challenge.update({
        where: { id: challenge.id },
        data: { translations: toTranslationsColumn(translations) },
      });
      translatedCount++;
    }

    this.logger.log(
      `${translatedCount}/${challenges.length} défi(s) sans traduction traduit(s).`,
    );
    return translatedCount;
  }
}

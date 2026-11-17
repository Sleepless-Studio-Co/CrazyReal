/**
 * Langues dans lesquelles les défis globaux sont traduits, avec le code
 * `target_lang` DeepL correspondant. Les défis sont écrits en français : le
 * français n'apparaît donc pas ici, il reste dans `title` / `description`.
 *
 * Pour ajouter une langue, il suffit d'ajouter une entrée puis de lancer
 * `npm run translate:challenges` pour rattraper les défis existants.
 */
export const CHALLENGE_LOCALES = {
  en: 'EN-US',
  es: 'ES',
  pt: 'PT-BR',
  de: 'DE',
} as const;

export type ChallengeLocale = keyof typeof CHALLENGE_LOCALES;

export const SOURCE_LOCALE = 'fr';

export interface ChallengeTranslation {
  title: string;
  description: string;
  /** Corrigée à la main par un admin : jamais écrasée par une retraduction. */
  manual?: boolean;
}

export type ChallengeTranslations = Partial<
  Record<ChallengeLocale, ChallengeTranslation>
>;

export function isChallengeLocale(value: string): value is ChallengeLocale {
  return Object.prototype.hasOwnProperty.call(CHALLENGE_LOCALES, value);
}

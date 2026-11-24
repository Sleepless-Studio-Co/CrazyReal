import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/** Termes jamais traduits (noms propres de l'app). */
const PROTECTED_TERMS = /CrazyReal/g;
const KEEP_TAG = 'keep';

/**
 * Client minimal de l'API DeepL (https://developers.deepl.com), via le `fetch`
 * global comme MailService : aucune dépendance supplémentaire.
 *
 * La clé vient de `API_TRADUCTION`. Une clé de l'offre gratuite se termine par
 * `:fx` et doit viser api-free.deepl.com. Le service ne lève jamais d'erreur :
 * en cas de problème il log et renvoie `null`, pour que la création d'un défi
 * ne dépende jamais de DeepL.
 */
@Injectable()
export class DeepLService {
  private readonly logger = new Logger(DeepLService.name);
  private readonly apiKey?: string;
  private readonly endpoint: string;
  private static readonly TIMEOUT_MS = 10_000;

  constructor(configService: ConfigService) {
    this.apiKey =
      configService.get<string>('API_TRADUCTION')?.trim() || undefined;
    this.endpoint = this.apiKey?.endsWith(':fx')
      ? 'https://api-free.deepl.com/v2/translate'
      : 'https://api.deepl.com/v2/translate';

    if (!this.apiKey) {
      this.logger.warn(
        'API_TRADUCTION non défini : les défis ne seront pas traduits.',
      );
    }
  }

  get isConfigured(): boolean {
    return Boolean(this.apiKey);
  }

  /**
   * Traduit `texts` (en français) vers `targetLang` (code DeepL, ex. `EN-US`).
   * Renvoie les traductions dans le même ordre, ou `null` en cas d'échec.
   */
  async translate(texts: string[], targetLang: string): Promise<string[] | null> {
    if (!this.apiKey) return null;
    if (texts.length === 0) return [];

    try {
      const response = await fetch(this.endpoint, {
        method: 'POST',
        headers: {
          Authorization: `DeepL-Auth-Key ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          text: texts.map(protect),
          source_lang: 'FR',
          target_lang: targetLang,
          // Le mode XML permet d'exclure les termes protégés de la traduction.
          tag_handling: 'xml',
          ignore_tags: [KEEP_TAG],
        }),
        signal: AbortSignal.timeout(DeepLService.TIMEOUT_MS),
      });

      if (!response.ok) {
        const body = await response.text().catch(() => '');
        this.logger.error(
          `DeepL a refusé la traduction vers ${targetLang} (status ${response.status}) : ${body}`,
        );
        return null;
      }

      const data = (await response.json()) as {
        translations?: { text: string }[];
      };
      const translations = data.translations?.map((t) => unprotect(t.text));
      if (!translations || translations.length !== texts.length) {
        this.logger.error(`Réponse DeepL inattendue pour ${targetLang}`);
        return null;
      }
      return translations;
    } catch (error) {
      this.logger.error(
        `Impossible de joindre DeepL pour ${targetLang}`,
        error as Error,
      );
      return null;
    }
  }
}

/** Échappe le texte pour le mode XML et entoure les termes protégés. */
export function protect(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(PROTECTED_TERMS, (term) => `<${KEEP_TAG}>${term}</${KEEP_TAG}>`);
}

/** Inverse de `protect` sur le texte renvoyé par DeepL. */
export function unprotect(text: string): string {
  return text
    .replace(new RegExp(`</?${KEEP_TAG}>`, 'g'), '')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');
}

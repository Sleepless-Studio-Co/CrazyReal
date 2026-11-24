import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import type { Request } from 'express';
import { map, Observable } from 'rxjs';
import {
  ChallengeLocale,
  ChallengeTranslations,
  isChallengeLocale,
  SOURCE_LOCALE,
} from './translation.constants';

/**
 * Localise les défis dans toutes les réponses HTTP, selon `Accept-Language` :
 * tout objet portant un champ `translations` (un défi, y compris celui joint à
 * un post) voit son `title` / `description` remplacés par la traduction, puis
 * `translations` est retiré. Sans header, en français ou dans une langue non
 * traduite, le texte d'origine est renvoyé, comme avant.
 *
 * Les routes /admin sont laissées telles quelles : l'admin édite le texte
 * français et voit les traductions brutes.
 */
@Injectable()
export class ChallengeLocaleInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType() !== 'http') return next.handle();

    const request = context.switchToHttp().getRequest<Request>();
    if (request.path?.startsWith('/admin')) return next.handle();

    const locale = resolveChallengeLocale(request.headers['accept-language']);
    return next.handle().pipe(map((body) => localizeChallenges(body, locale)));
  }
}

/**
 * Choisit la langue de traduction à partir d'un header Accept-Language
 * (ex. `pt-BR,pt;q=0.9,en;q=0.8`). Renvoie `null` pour le français ou si
 * aucune langue demandée n'est traduite.
 */
export function resolveChallengeLocale(
  header: string | string[] | undefined,
): ChallengeLocale | null {
  const raw = Array.isArray(header) ? header.join(',') : header;
  if (!raw) return null;

  const ranked = raw
    .split(',')
    .map((part, index) => {
      const [tag, ...params] = part.trim().split(';');
      const q = params
        .map((p) => p.trim())
        .find((p) => p.startsWith('q='));
      return {
        lang: tag.trim().split('-')[0].toLowerCase(),
        q: q ? Number(q.slice(2)) : 1,
        index,
      };
    })
    .filter((entry) => entry.lang && entry.q > 0)
    .sort((a, b) => b.q - a.q || a.index - b.index);

  for (const { lang } of ranked) {
    if (lang === SOURCE_LOCALE) return null;
    if (isChallengeLocale(lang)) return lang;
  }
  return null;
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (value === null || typeof value !== 'object') return false;
  const proto = Object.getPrototypeOf(value);
  return proto === Object.prototype || proto === null;
}

/** Copie `value` en localisant chaque défi rencontré (sans muter l'original). */
export function localizeChallenges(
  value: unknown,
  locale: ChallengeLocale | null,
): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => localizeChallenges(item, locale));
  }
  if (!isPlainObject(value)) return value;

  const result: Record<string, unknown> = {};
  for (const [key, child] of Object.entries(value)) {
    if (key === 'translations') continue;
    result[key] = localizeChallenges(child, locale);
  }

  if ('translations' in value && locale) {
    const translation = (value.translations as ChallengeTranslations | null)?.[
      locale
    ];
    if (translation) {
      if ('title' in value) result.title = translation.title;
      if ('description' in value && translation.description) {
        result.description = translation.description;
      }
    }
  }
  return result;
}

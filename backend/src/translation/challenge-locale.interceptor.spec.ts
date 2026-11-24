import { CallHandler, ExecutionContext } from '@nestjs/common';
import { lastValueFrom, of } from 'rxjs';
import {
  ChallengeLocaleInterceptor,
  localizeChallenges,
  resolveChallengeLocale,
} from './challenge-locale.interceptor';

const translations = {
  en: { title: 'Sunny selfie', description: 'In the sun' },
  es: { title: 'Selfie soleado', description: '' },
};

describe('resolveChallengeLocale', () => {
  it.each([
    [undefined, null],
    ['', null],
    ['fr-FR,fr;q=0.9', null],
    ['en', 'en'],
    ['pt-BR,pt;q=0.9,en;q=0.8', 'pt'],
    ['DE-de', 'de'],
    // Langue non traduite : on passe à la suivante.
    ['it,es;q=0.5', 'es'],
    // Le poids q prime sur l'ordre.
    ['en;q=0.2,de;q=0.9', 'de'],
    // Le français avant une langue traduite => texte d'origine.
    ['fr,en;q=0.8', null],
    ['ja', null],
  ])('%s => %s', (header, expected) => {
    expect(resolveChallengeLocale(header)).toBe(expected);
  });
});

describe('localizeChallenges', () => {
  const challenge = {
    id: 1,
    title: 'Selfie au soleil',
    description: 'Au soleil',
    date: new Date('2026-11-17T00:00:00Z'),
    translations,
  };

  it('should replace title and description and hide translations', () => {
    expect(localizeChallenges(challenge, 'en')).toEqual({
      id: 1,
      title: 'Sunny selfie',
      description: 'In the sun',
      date: challenge.date,
    });
  });

  it('should keep the French text without locale or translation', () => {
    const { translations: _, ...french } = challenge;
    expect(localizeChallenges(challenge, null)).toEqual(french);
    expect(localizeChallenges(challenge, 'de')).toEqual(french);
  });

  it('should keep the original description when the translation is empty', () => {
    expect(localizeChallenges(challenge, 'es')).toMatchObject({
      title: 'Selfie soleado',
      description: 'Au soleil',
    });
  });

  it('should localize challenges nested in posts and arrays without mutating them', () => {
    const posts = [{ id: 9, challenge: { id: 1, title: 'Selfie', type: 'WEEKLY_A', translations } }];

    expect(localizeChallenges(posts, 'en')).toEqual([
      { id: 9, challenge: { id: 1, title: 'Sunny selfie', type: 'WEEKLY_A' } },
    ]);
    expect(posts[0].challenge.title).toBe('Selfie');
  });

  it('should strip null translations (group challenges)', () => {
    expect(localizeChallenges({ id: 2, title: 'Groupe', translations: null }, 'en')).toEqual({
      id: 2,
      title: 'Groupe',
    });
  });

  it('should leave primitives and dates alone', () => {
    const date = new Date();
    expect(localizeChallenges('x', 'en')).toBe('x');
    expect(localizeChallenges(null, 'en')).toBeNull();
    expect(localizeChallenges(date, 'en')).toBe(date);
  });
});

describe('ChallengeLocaleInterceptor', () => {
  const interceptor = new ChallengeLocaleInterceptor();
  const body = { id: 1, title: 'Selfie', translations };

  function run(path: string, acceptLanguage?: string) {
    const context = {
      getType: () => 'http',
      switchToHttp: () => ({
        getRequest: () => ({ path, headers: { 'accept-language': acceptLanguage } }),
      }),
    } as unknown as ExecutionContext;
    const next: CallHandler = { handle: () => of(body) };
    return lastValueFrom(interceptor.intercept(context, next));
  }

  it('should localize public routes', async () => {
    await expect(run('/challenge/current', 'en')).resolves.toEqual({
      id: 1,
      title: 'Sunny selfie',
    });
  });

  it('should leave admin routes untouched', async () => {
    await expect(run('/admin/challenges', 'en')).resolves.toBe(body);
  });
});

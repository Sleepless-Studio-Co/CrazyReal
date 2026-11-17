import { ConfigService } from '@nestjs/config';
import { DeepLService, protect, unprotect } from './deepl.service';

function makeService(apiKey?: string) {
  const config = { get: jest.fn().mockReturnValue(apiKey) } as unknown as ConfigService;
  return new DeepLService(config);
}

describe('DeepLService', () => {
  const fetchMock = jest.fn();

  beforeEach(() => {
    fetchMock.mockReset();
    global.fetch = fetchMock as unknown as typeof fetch;
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
  });

  afterEach(() => jest.restoreAllMocks());

  it('should not call DeepL without an API key', async () => {
    const service = makeService(undefined);

    expect(service.isConfigured).toBe(false);
    await expect(service.translate(['Bonjour'], 'EN-US')).resolves.toBeNull();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('should use the free endpoint for a ":fx" key and return translations in order', async () => {
    fetchMock.mockResolvedValue({
      ok: true,
      json: async () => ({ translations: [{ text: 'Hello' }, { text: 'World' }] }),
    });
    const service = makeService('abc:fx');

    await expect(service.translate(['Bonjour', 'Monde'], 'EN-US')).resolves.toEqual([
      'Hello',
      'World',
    ]);

    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe('https://api-free.deepl.com/v2/translate');
    expect(init.headers.Authorization).toBe('DeepL-Auth-Key abc:fx');
    expect(JSON.parse(init.body)).toMatchObject({
      text: ['Bonjour', 'Monde'],
      source_lang: 'FR',
      target_lang: 'EN-US',
    });
  });

  it('should use the pro endpoint for a paid key', async () => {
    fetchMock.mockResolvedValue({
      ok: true,
      json: async () => ({ translations: [{ text: 'Hi' }] }),
    });

    await makeService('pro-key').translate(['Salut'], 'DE');

    expect(fetchMock.mock.calls[0][0]).toBe('https://api.deepl.com/v2/translate');
  });

  it('should return null when DeepL rejects the request (quota, bad key…)', async () => {
    fetchMock.mockResolvedValue({ ok: false, status: 456, text: async () => 'Quota exceeded' });

    await expect(makeService('abc:fx').translate(['Bonjour'], 'ES')).resolves.toBeNull();
  });

  it('should return null when DeepL is unreachable', async () => {
    fetchMock.mockRejectedValue(new Error('timeout'));

    await expect(makeService('abc:fx').translate(['Bonjour'], 'ES')).resolves.toBeNull();
  });

  it('should return null when the response does not match the request', async () => {
    fetchMock.mockResolvedValue({ ok: true, json: async () => ({ translations: [] }) });

    await expect(makeService('abc:fx').translate(['Bonjour'], 'ES')).resolves.toBeNull();
  });
});

describe('protect / unprotect', () => {
  it('should keep CrazyReal untranslated and escape XML characters', () => {
    expect(protect('Poste sur CrazyReal & gagne <3')).toBe(
      'Poste sur <keep>CrazyReal</keep> &amp; gagne &lt;3',
    );
  });

  it('should restore the original characters', () => {
    expect(unprotect('Post on <keep>CrazyReal</keep> &amp; win &lt;3')).toBe(
      'Post on CrazyReal & win <3',
    );
  });
});

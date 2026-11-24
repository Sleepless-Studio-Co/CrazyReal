import { MailService } from './mail.service';
import { ConfigService } from '@nestjs/config';

describe('MailService', () => {
  const configGet = jest.fn();
  const configService = { get: configGet } as unknown as ConfigService;

  let originalFetch: typeof fetch;

  beforeEach(() => {
    jest.clearAllMocks();
    originalFetch = global.fetch;
  });

  afterEach(() => {
    global.fetch = originalFetch;
  });

  describe('isConfigured', () => {
    it('is false when RESEND_API_KEY is not set', () => {
      configGet.mockReturnValue(undefined);
      const service = new MailService(configService);
      expect(service.isConfigured).toBe(false);
    });

    it('is true when RESEND_API_KEY is set', () => {
      configGet.mockImplementation((key: string) =>
        key === 'RESEND_API_KEY' ? 're_123' : undefined,
      );
      const service = new MailService(configService);
      expect(service.isConfigured).toBe(true);
    });
  });

  describe('send', () => {
    it('logs and skips delivery when not configured', async () => {
      configGet.mockReturnValue(undefined);
      const fetchMock = jest.fn();
      global.fetch = fetchMock as unknown as typeof fetch;

      const service = new MailService(configService);
      await expect(
        service.send({ to: 'a@b.com', subject: 'Hi', html: '<p>hi</p>' }),
      ).resolves.toBeUndefined();
      expect(fetchMock).not.toHaveBeenCalled();
    });

    it('sends an email through the Resend API when configured', async () => {
      configGet.mockImplementation((key: string) =>
        key === 'RESEND_API_KEY'
          ? 're_123'
          : key === 'MAIL_FROM'
            ? 'N <n@x.co>'
            : undefined,
      );
      const fetchMock = jest.fn().mockResolvedValue({ ok: true, status: 200 });
      global.fetch = fetchMock as unknown as typeof fetch;

      const service = new MailService(configService);
      await service.send({ to: 'a@b.com', subject: 'Hi', html: '<p>hi</p>' });

      expect(fetchMock).toHaveBeenCalledWith(
        'https://api.resend.com/emails',
        expect.objectContaining({
          method: 'POST',
          headers: expect.objectContaining({ Authorization: 'Bearer re_123' }),
          body: expect.stringContaining('"to":["a@b.com"]'),
        }),
      );
    });

    it('throws when the Resend API rejects the email', async () => {
      configGet.mockReturnValue('re_123');
      const fetchMock = jest.fn().mockResolvedValue({
        ok: false,
        status: 422,
        text: () => Promise.resolve('bad request'),
      });
      global.fetch = fetchMock as unknown as typeof fetch;

      const service = new MailService(configService);
      await expect(
        service.send({ to: 'a@b.com', subject: 'Hi', html: '<p>hi</p>' }),
      ).rejects.toThrow('Email delivery failed (status 422)');
    });

    it('rethrows network errors', async () => {
      configGet.mockReturnValue('re_123');
      const boom = new Error('network down');
      const fetchMock = jest.fn().mockRejectedValue(boom);
      global.fetch = fetchMock as unknown as typeof fetch;

      const service = new MailService(configService);
      await expect(
        service.send({ to: 'a@b.com', subject: 'Hi', html: '<p>hi</p>' }),
      ).rejects.toBe(boom);
    });
  });
});

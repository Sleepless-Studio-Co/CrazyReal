import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

interface SendEmailParams {
  to: string;
  subject: string;
  html: string;
  text?: string;
}

/**
 * Thin wrapper around the Resend email API (https://resend.com).
 *
 * It talks to the Resend REST endpoint with the global `fetch` so it requires
 * no extra runtime dependency. When `RESEND_API_KEY` is not configured the
 * service runs in "dev" mode: instead of sending it logs the message (and any
 * verification link) so the flow stays functional locally without an account.
 */
@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private readonly apiKey?: string;
  private readonly from: string;
  private static readonly RESEND_ENDPOINT = 'https://api.resend.com/emails';

  constructor(private readonly configService: ConfigService) {
    this.apiKey = this.configService.get<string>('RESEND_API_KEY')?.trim() || undefined;
    this.from =
      this.configService.get<string>('MAIL_FROM')?.trim() ||
      'CrazyReal <onboarding@resend.dev>';
  }

  get isConfigured(): boolean {
    return Boolean(this.apiKey);
  }

  async send({ to, subject, html, text }: SendEmailParams): Promise<void> {
    if (!this.apiKey) {
      this.logger.warn(
        `RESEND_API_KEY not set — email to <${to}> ("${subject}") was not sent. ` +
          `Configure RESEND_API_KEY to enable real delivery.`,
      );
      this.logger.debug(`[dev email] ${text ?? html}`);
      return;
    }

    let response: Response;
    try {
      response = await fetch(MailService.RESEND_ENDPOINT, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: this.from,
          to: [to],
          subject,
          html,
          ...(text ? { text } : {}),
        }),
      });
    } catch (error) {
      this.logger.error(`Failed to reach Resend API for <${to}>`, error as Error);
      throw error;
    }

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      this.logger.error(
        `Resend API rejected email to <${to}> (status ${response.status}): ${body}`,
      );
      throw new Error(`Email delivery failed (status ${response.status})`);
    }

    this.logger.log(`Verification email sent to <${to}>`);
  }
}

import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';

interface VerifiableUser {
  id: number;
  email: string;
  username: string;
}

@Injectable()
export class EmailVerificationService {
  private readonly logger = new Logger(EmailVerificationService.name);

  /** How long a verification link stays valid. */
  private static readonly TOKEN_TTL_MS = 24 * 60 * 60 * 1000; // 24h
  /** Minimum delay between two "resend" requests for the same user. */
  private static readonly RESEND_COOLDOWN_MS = 60 * 1000; // 60s

  constructor(
    private readonly prisma: PrismaService,
    private readonly mailService: MailService,
    private readonly configService: ConfigService,
  ) {}

  /**
   * Generates a fresh verification token for the user (invalidating any
   * previous one) and emails them the verification link. Sending failures are
   * swallowed and logged so they never break the surrounding flow
   * (e.g. registration) — the user can always trigger a resend.
   */
  async createAndSend(user: VerifiableUser): Promise<void> {
    const token = await this.issueToken(user.id);
    const verifyUrl = this.buildVerifyUrl(token);

    try {
      await this.mailService.send({
        to: user.email,
        subject: 'Verify your CrazyReal email',
        html: this.buildHtml(user.username, verifyUrl),
        text: this.buildText(user.username, verifyUrl),
      });
    } catch (error) {
      this.logger.error(
        `Could not send verification email to <${user.email}>`,
        error as Error,
      );
    }
  }

  /** Verifies a token and marks the owning user as verified. */
  async verify(token: string): Promise<{ email: string }> {
    if (!token || typeof token !== 'string') {
      throw new BadRequestException('Missing verification token');
    }

    const record = await this.prisma.emailVerificationToken.findUnique({
      where: { token },
      include: { user: true },
    });

    if (!record) {
      throw new BadRequestException('Invalid or expired verification token');
    }

    if (record.expiresAt.getTime() < Date.now()) {
      await this.prisma.emailVerificationToken.delete({ where: { id: record.id } });
      throw new BadRequestException('Verification token has expired');
    }

    // Mark verified and clear all outstanding tokens for this user.
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: record.userId },
        data: { emailVerified: true, emailVerifiedAt: new Date() },
      }),
      this.prisma.emailVerificationToken.deleteMany({
        where: { userId: record.userId },
      }),
    ]);

    return { email: record.user.email };
  }

  /** Re-issues and re-sends a verification email for an existing user. */
  async resendForUser(userId: number): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, username: true, emailVerified: true },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (user.emailVerified) {
      throw new BadRequestException('Email already verified');
    }

    await this.assertNotRateLimited(userId);
    await this.createAndSend(user);
  }

  private async issueToken(userId: number): Promise<string> {
    const token = randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + EmailVerificationService.TOKEN_TTL_MS);

    await this.prisma.$transaction([
      this.prisma.emailVerificationToken.deleteMany({ where: { userId } }),
      this.prisma.emailVerificationToken.create({
        data: { token, userId, expiresAt },
      }),
    ]);

    return token;
  }

  private async assertNotRateLimited(userId: number): Promise<void> {
    const latest = await this.prisma.emailVerificationToken.findFirst({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });

    if (
      latest &&
      Date.now() - latest.createdAt.getTime() <
        EmailVerificationService.RESEND_COOLDOWN_MS
    ) {
      throw new BadRequestException(
        'Please wait a moment before requesting another verification email',
      );
    }
  }

  private buildVerifyUrl(token: string): string {
    const base = (
      this.configService.get<string>('APP_PUBLIC_URL')?.trim() ||
      `http://localhost:${this.configService.get<string>('API_PORT') || '3000'}`
    ).replace(/\/+$/, '');
    return `${base}/auth/verify-email?token=${encodeURIComponent(token)}`;
  }

  private buildText(username: string, verifyUrl: string): string {
    return [
      `Hi ${username},`,
      '',
      'Welcome to CrazyReal! Please confirm your email address by opening the link below:',
      verifyUrl,
      '',
      'This link expires in 24 hours. If you did not create an account, you can ignore this email.',
    ].join('\n');
  }

  private buildHtml(username: string, verifyUrl: string): string {
    const safeUser = this.escapeHtml(username);
    return `<!doctype html>
<html>
  <body style="margin:0;background:#FBF1E0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#3B2A21;">
    <div style="max-width:480px;margin:0 auto;padding:32px 24px;">
      <h1 style="font-size:22px;margin:0 0 16px;">Confirm your email</h1>
      <p style="font-size:15px;line-height:1.5;margin:0 0 16px;">Hi ${safeUser}, welcome to <strong>CrazyReal</strong>! Tap the button below to verify your email address.</p>
      <p style="margin:24px 0;">
        <a href="${verifyUrl}" style="display:inline-block;background:#B85C38;color:#FFF7E6;text-decoration:none;padding:12px 24px;border-radius:12px;font-weight:600;">Verify my email</a>
      </p>
      <p style="font-size:13px;line-height:1.5;color:#6A4A3B;margin:0 0 8px;">Or copy this link into your browser:</p>
      <p style="font-size:13px;word-break:break-all;color:#6A4A3B;margin:0 0 24px;"><a href="${verifyUrl}" style="color:#B85C38;">${verifyUrl}</a></p>
      <p style="font-size:12px;color:#9A7B6B;margin:0;">This link expires in 24 hours. If you did not create an account, you can safely ignore this email.</p>
    </div>
  </body>
</html>`;
  }

  private escapeHtml(value: string): string {
    return value
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }
}

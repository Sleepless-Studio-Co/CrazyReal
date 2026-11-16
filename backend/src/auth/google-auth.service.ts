import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { LoginTicket, OAuth2Client } from 'google-auth-library';

/** Normalized subset of a Google ID token payload we rely on. */
export interface GoogleProfile {
  /** Google account id (the `sub` claim). */
  googleId: string;
  email: string;
  emailVerified: boolean;
  name?: string;
  picture?: string;
}

/**
 * Verifies Google ID tokens issued by the mobile Google Sign-In flow.
 *
 * The accepted audiences come from `GOOGLE_CLIENT_ID`: the OAuth "Web" (server)
 * client id used by Android, and optionally the iOS client id. Several values
 * may be provided, comma-separated.
 */
@Injectable()
export class GoogleAuthService {
  private readonly logger = new Logger(GoogleAuthService.name);
  private readonly client = new OAuth2Client();

  constructor(private readonly configService: ConfigService) {}

  private getAudiences(): string[] {
    const raw = this.configService.get<string>('GOOGLE_CLIENT_ID') ?? '';
    return raw
      .split(',')
      .map((value) => value.trim())
      .filter((value) => value.length > 0);
  }

  /** Verifies the token signature/audience and returns the Google profile. */
  async verify(idToken: string): Promise<GoogleProfile> {
    const audiences = this.getAudiences();
    if (audiences.length === 0) {
      this.logger.error('GOOGLE_CLIENT_ID is not configured');
      throw new UnauthorizedException('Google sign-in is not configured');
    }

    let ticket: LoginTicket;
    try {
      ticket = await this.client.verifyIdToken({ idToken, audience: audiences });
    } catch (error) {
      this.logger.warn(
        `Google ID token verification failed: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      throw new UnauthorizedException('Invalid Google token');
    }

    const payload = ticket.getPayload();
    if (!payload?.sub || !payload.email) {
      throw new UnauthorizedException('Google token is missing required claims');
    }

    const profile: GoogleProfile = {
      googleId: payload.sub,
      email: payload.email.toLowerCase(),
      emailVerified: payload.email_verified === true,
    };
    if (payload.name) profile.name = payload.name;
    if (payload.picture) profile.picture = payload.picture;

    return profile;
  }
}

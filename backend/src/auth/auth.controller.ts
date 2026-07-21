import {
  Body,
  Controller,
  Get,
  Patch,
  Post,
  Query,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { CurrentUser } from './current-user.decorator';
import { Throttle } from '@nestjs/throttler';
import { ApiBearerAuth } from '@nestjs/swagger';
import type { ValidatedUser } from './interfaces/auth-user.interface';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('register')
  @Throttle({ default: { limit: 3, ttl: 60000 } })
  async register(
    @Body() registerDto: { email: string; password: string; username: string },
  ) {
    return this.authService.register(
      registerDto.email,
      registerDto.password,
      registerDto.username,
    );
  }

  @Post('login')
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  async login(@Body() loginDto: { email: string; password: string }) {
    return this.authService.login(loginDto.email, loginDto.password);
  }

  @Post('refresh')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async refresh(@Body() body: { refresh_token: string }) {
    return this.authService.refresh(body.refresh_token);
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  async logout(@Body() body: { refresh_token: string }) {
    await this.authService.revokeRefreshToken(body.refresh_token);
    return { message: 'Logged out successfully' };
  }

  @Get('verify-email')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async verifyEmail(@Query('token') token: string, @Res() res: Response) {
    try {
      await this.authService.verifyEmail(token);
      res
        .status(200)
        .type('html')
        .send(this.renderVerificationPage(true, 'Your email address is now verified. You can head back to CrazyReal.'));
    } catch (error) {
      const message =
        (error && typeof error === 'object' && 'message' in error
          ? String((error as { message: unknown }).message)
          : '') || 'This verification link is invalid or has expired.';
      res
        .status(400)
        .type('html')
        .send(this.renderVerificationPage(false, message));
    }
  }

  @Post('resend-verification')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @Throttle({ default: { limit: 3, ttl: 60000 } })
  async resendVerification(@CurrentUser() user: ValidatedUser) {
    return this.authService.resendVerificationEmail(user.userId);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  getProfile(@CurrentUser() user: ValidatedUser) {
    return this.authService.getMe(user.userId);
  }

  @Patch('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  updateProfile(
    @CurrentUser() user: ValidatedUser,
    @Body() body: { email?: string; username?: string },
  ) {
    return this.authService.updateProfile(user.userId, body);
  }

  private renderVerificationPage(success: boolean, message: string): string {
    const accent = success ? '#2E7D32' : '#B85C38';
    const title = success ? 'Email verified 🎉' : 'Verification failed';
    const icon = success ? '✓' : '!';
    const safeMessage = message
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
    return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${title}</title>
  </head>
  <body style="margin:0;background:#FBF1E0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#3B2A21;">
    <div style="max-width:420px;margin:64px auto;padding:32px 24px;background:#FFF7E6;border-radius:24px;box-shadow:0 12px 32px rgba(46,27,15,0.15);text-align:center;">
      <div style="width:72px;height:72px;line-height:72px;margin:0 auto 16px;border-radius:50%;background:${accent};color:#FFF7E6;font-size:36px;font-weight:700;">${icon}</div>
      <h1 style="font-size:22px;margin:0 0 12px;">${title}</h1>
      <p style="font-size:15px;line-height:1.5;color:#6A4A3B;margin:0;">${safeMessage}</p>
    </div>
  </body>
</html>`;
  }
}

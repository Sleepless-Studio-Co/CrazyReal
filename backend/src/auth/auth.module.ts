import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { UsersModule } from '../users/users.module';
import { JwtStrategy } from './jwt.strategy';
import { JWT_CONFIG_KEYS } from './jwt.config';
import { EmailVerificationService } from './email-verification.service';
import { MailModule } from '../mail/mail.module';

@Module({
  imports: [
    UsersModule,
    MailModule,
    PassportModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        secret: configService.getOrThrow<string>(JWT_CONFIG_KEYS.secret),
        signOptions: {
          expiresIn:
            (configService.get<string>(JWT_CONFIG_KEYS.accessExpiration) ||
              '15m') as any,
        },
      }),
      inject: [ConfigService],
    }),
  ],
  providers: [AuthService, JwtStrategy, EmailVerificationService],
  controllers: [AuthController],
  exports: [AuthService],
})
export class AuthModule {}

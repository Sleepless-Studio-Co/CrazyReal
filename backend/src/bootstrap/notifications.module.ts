import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { JWT_CONFIG_KEYS } from '../auth/jwt.config';
import { PrismaModule } from '../prisma/prisma.module';
import { NotificationGateway } from './notification.gateway';

@Module({
  imports: [
    PrismaModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => ({
        secret: configService.getOrThrow<string>(JWT_CONFIG_KEYS.secret),
      }),
      inject: [ConfigService],
    }),
  ],
  providers: [NotificationGateway],
  exports: [NotificationGateway],
})
export class NotificationsModule {}
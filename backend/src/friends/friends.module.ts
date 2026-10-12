import { Module } from '@nestjs/common';
import { FriendsService } from './friends.service';
import { FriendsController } from './friends.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { NotificationsModule } from '../bootstrap/notifications.module';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [PrismaModule, AuthModule, NotificationsModule],
  controllers: [FriendsController],
  providers: [FriendsService],
})
export class FriendsModule {}
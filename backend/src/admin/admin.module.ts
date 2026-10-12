import { Module } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { AdminGuard } from '../auth/admin.guard';
import { NotificationsModule } from '../bootstrap/notifications.module';

@Module({
  imports: [PrismaModule, NotificationsModule],
  providers: [AdminService, AdminGuard],
  controllers: [AdminController],
})
export class AdminModule {}

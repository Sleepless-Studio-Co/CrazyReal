import { Module } from '@nestjs/common';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';
import { StreakModule } from '../streak/streak.module';

@Module({
  imports: [StreakModule],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService], // Exporte pour être utilisé dans auth module
})
export class UsersModule {}

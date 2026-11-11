import { Module } from '@nestjs/common';
import { StreakService } from './streak.service';

@Module({
  providers: [StreakService],
  exports: [StreakService],
})
export class StreakModule {}

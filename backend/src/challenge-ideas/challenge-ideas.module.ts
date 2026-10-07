import { Module } from '@nestjs/common';
import { ChallengeIdeasController } from './challenge-ideas.controller';

@Module({
  controllers: [ChallengeIdeasController],
})
export class ChallengeIdeasModule {}

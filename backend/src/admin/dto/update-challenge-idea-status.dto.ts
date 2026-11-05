import { ChallengeIdeaStatus } from '@prisma/client';
import { IsEnum } from 'class-validator';

export class UpdateChallengeIdeaStatusDto {
  @IsEnum(ChallengeIdeaStatus)
  status: ChallengeIdeaStatus;
}

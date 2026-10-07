import { PartialType } from '@nestjs/swagger';
import { CreateChallengeDto } from './create-challenge.dto';

export class UpdateChallengeDto extends PartialType(CreateChallengeDto) {}

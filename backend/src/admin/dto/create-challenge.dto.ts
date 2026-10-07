import { ChallengeType } from '@prisma/client';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateChallengeDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  title: string;

  @IsString()
  @MaxLength(500)
  @IsOptional()
  description?: string;

  // Début du défi (ISO). La fin est dérivée du `type` : 24h pour SPECIAL, 84h sinon.
  @IsDateString()
  @IsOptional()
  date?: string;

  @IsEnum(ChallengeType)
  @IsOptional()
  type?: ChallengeType;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}

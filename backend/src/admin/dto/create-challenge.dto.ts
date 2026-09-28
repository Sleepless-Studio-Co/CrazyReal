import { ChallengeType } from '@prisma/client';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  Max,
  Min,
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

  // Début du défi (ISO).
  @IsDateString()
  @IsOptional()
  date?: string;

  @IsEnum(ChallengeType)
  @IsOptional()
  type?: ChallengeType;

  @IsInt()
  @Min(1)
  @Max(8760)
  @IsOptional()
  durationHours?: number;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}

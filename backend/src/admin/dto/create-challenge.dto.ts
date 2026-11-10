import { ChallengeType } from '@prisma/client';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsNumber,
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

  @IsDateString()
  @IsOptional()
  endsAt?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsNumber()
  @Min(-90)
  @Max(90)
  @IsOptional()
  latitude?: number | null;

  @IsNumber()
  @Min(-180)
  @Max(180)
  @IsOptional()
  longitude?: number | null;

  @IsString()
  @MaxLength(30)
  @IsOptional()
  icon?: string | null;
}

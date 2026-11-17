import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

/** Traduction saisie à la main par un admin (mêmes limites que le défi). */
export class UpdateChallengeTranslationDto {
  @ApiProperty({ maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  title: string;

  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;
}

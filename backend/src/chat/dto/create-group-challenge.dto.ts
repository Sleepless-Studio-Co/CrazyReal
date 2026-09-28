import { IsDateString, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateGroupChallengeDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  title: string;

  @IsString()
  @MaxLength(500)
  @IsOptional()
  description?: string;

  // ISO date; défi actif de maintenant jusqu'à endsAt.
  @IsDateString()
  endsAt: string;
}

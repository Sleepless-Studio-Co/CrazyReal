import { IsString, MaxLength, MinLength } from 'class-validator';

export class CreateChallengeIdeaDto {
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  content: string;
}

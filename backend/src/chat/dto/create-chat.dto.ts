import { ArrayMaxSize, ArrayMinSize, IsInt, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateChatDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name: string;

  @IsInt({ each: true })
  @ArrayMinSize(1)
  @ArrayMaxSize(49)
  members: number[];
}

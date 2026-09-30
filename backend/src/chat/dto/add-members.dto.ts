import { ArrayMaxSize, ArrayMinSize, IsInt } from 'class-validator';

export class AddMembersDto {
  @IsInt({ each: true })
  @ArrayMinSize(1)
  @ArrayMaxSize(49)
  members: number[];
}

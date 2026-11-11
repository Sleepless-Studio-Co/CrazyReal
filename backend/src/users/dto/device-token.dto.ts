import { IsIn, IsString, MinLength } from 'class-validator';

export class DeviceTokenDto {
  @IsString()
  @MinLength(1)
  token: string;

  @IsString()
  @IsIn(['android', 'ios', 'web'])
  platform: string;
}

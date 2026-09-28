import { IsIn } from 'class-validator';

export const BASE_AVATAR_KEYS = [
  'ember',
  'sea',
  'citrus',
  'berry',
  'noon',
  'terra',
] as const;

export class UpdateAvatarKeyDto {
  @IsIn(BASE_AVATAR_KEYS)
  avatarKey: string;
}

import { IsBoolean } from 'class-validator';

export class UpdateNotificationsDto {
  @IsBoolean()
  notifyGroupMessages: boolean;

  @IsBoolean()
  notifyChallengeReminders: boolean;

  @IsBoolean()
  notifyFriendRequests: boolean;

  @IsBoolean()
  notifyNewChallenges: boolean;
}

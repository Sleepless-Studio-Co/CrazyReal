export interface AuthUser {
  id: number;
  email: string;
  username: string;
  avatarUrl?: string | null;
  avatarKey?: string | null;
  isPrivate: boolean;
  notifyGroupMessages?: boolean;
  notifyChallengeReminders?: boolean;
  notifyFriendRequests?: boolean;
  notifyNewChallenges?: boolean;
  emailVerified?: boolean;
  createdAt: Date;
}

export interface AuthUserWithPassword extends AuthUser {
  password: string;
}

export interface ValidatedUser {
  userId: number;
  email: string;
  username: string;
  avatarUrl?: string | null;
  avatarKey?: string | null;
}

export interface AuthUser {
  id: number;
  email: string;
  username: string;
  createdAt: Date;
}

export interface AuthUserWithPassword extends AuthUser {
  password: string;
}

export interface ValidatedUser {
  userId: number;
  email: string;
  username: string;
}

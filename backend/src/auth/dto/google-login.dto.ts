import { IsNotEmpty, IsString } from 'class-validator';

export class GoogleLoginDto {
  /** OIDC ID token returned by Google Sign-In on the device. */
  @IsString()
  @IsNotEmpty()
  idToken: string;
}

import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { ValidatedUser } from './interfaces/auth-user.interface';

export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): ValidatedUser => {
    const request = ctx.switchToHttp().getRequest<{ user: ValidatedUser }>();
    return request.user;
  },
);

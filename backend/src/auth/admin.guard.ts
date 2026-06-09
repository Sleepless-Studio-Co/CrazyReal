import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdminGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest();
    const user = req.user as { userId?: number } | undefined;
    if (!user?.userId) return false;

    const dbUser = await this.prisma.user.findUnique({ where: { id: user.userId } });
    return dbUser?.role === Role.ADMIN;
  }
}

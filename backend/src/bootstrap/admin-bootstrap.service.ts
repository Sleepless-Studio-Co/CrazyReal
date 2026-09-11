import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AdminBootstrapService {
  constructor(private readonly prisma: PrismaService) {}

  async createDefaultUser(): Promise<void> {
    const shouldBootstrapAdmin = process.env.BOOTSTRAP_ADMIN === 'true';
    if (!shouldBootstrapAdmin) {
      return;
    }

    const adminEmail = process.env.BOOTSTRAP_ADMIN_EMAIL;
    const adminPassword = process.env.BOOTSTRAP_ADMIN_PASSWORD;
    const adminUsername = process.env.BOOTSTRAP_ADMIN_USERNAME ?? 'admin';

    if (!adminEmail || !adminPassword) {
      throw new Error(
        'BOOTSTRAP_ADMIN=true requires BOOTSTRAP_ADMIN_EMAIL and BOOTSTRAP_ADMIN_PASSWORD',
      );
    }

    const existingUser = await this.prisma.user.findUnique({
      where: { email: adminEmail },
    });

    if (!existingUser) {
      const hashedPassword = await bcrypt.hash(adminPassword, 12);
      await this.prisma.user.create({
        data: {
          email: adminEmail,
          password: hashedPassword,
          username: adminUsername,
          role: 'ADMIN',
        },
      });
      console.log(`Admin bootstrap user created: ${adminEmail}`);
    } else {
      if (existingUser.role !== 'ADMIN') {
        await this.prisma.user.update({
          where: { email: adminEmail },
          data: { role: 'ADMIN' },
        });
        console.log(`Admin bootstrap user promoted to ADMIN: ${adminEmail}`);
      }
      console.log(`Admin bootstrap user already exists: ${adminEmail}`);
    }
  }
}

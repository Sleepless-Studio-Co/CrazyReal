import { Injectable, InternalServerErrorException, NotFoundException } from '@nestjs/common';
import { ChallengeType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  async importChallengesFromFile(): Promise<{ imported: number }> {
    try {
      // Prefer prisma/challenges.json relative to project root (process.cwd())
      let file = path.join(process.cwd(), 'prisma', 'challenges.json');
      // Fallback: when process.cwd() is project root's parent, try locating from compiled runtime
      if (!fs.existsSync(file)) {
        const alt = path.join(__dirname, '..', '..', 'prisma', 'challenges.json');
        if (fs.existsSync(alt)) file = alt;
      }

      if (!fs.existsSync(file)) {
        throw new NotFoundException('prisma/challenges.json not found');
      }

      const raw = fs.readFileSync(file, 'utf-8');
      const items = JSON.parse(raw || '[]');

      const data = items.map((c: any) => ({
        title: c.title,
        description: c.description || '',
        date: c.date ? new Date(c.date) : new Date(),
        type: c.type || ChallengeType.WEEKLY_A,
        isActive: c.isActive !== undefined ? c.isActive : true,
      }));

      if (data.length === 0) return { imported: 0 };

      const res = await this.prisma.challenge.createMany({ data, skipDuplicates: true });
      return { imported: res.count };
    } catch (e: any) {
      if (e instanceof NotFoundException) {
        throw e;
      }

      throw new InternalServerErrorException(e?.message || String(e));
    }
  }

  async listChallenges() {
    return this.prisma.challenge.findMany({ orderBy: { date: 'desc' } });
  }
}

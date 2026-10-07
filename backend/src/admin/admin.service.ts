import {
  ConflictException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { ChallengeType, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateChallengeDto } from './dto/create-challenge.dto';
import { UpdateChallengeDto } from './dto/update-challenge.dto';
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
    // Seuls les défis globaux sont administrables ici ; ceux d'un groupe
    // appartiennent à leur conversation.
    return this.prisma.challenge.findMany({
      where: { conversationId: null },
      orderBy: { date: 'desc' },
      include: { _count: { select: { posts: true } } },
    });
  }

  async createChallenge(dto: CreateChallengeDto) {
    try {
      return await this.prisma.challenge.create({
        data: {
          title: dto.title.trim(),
          description: dto.description?.trim() ?? '',
          date: dto.date ? new Date(dto.date) : new Date(),
          type: dto.type ?? ChallengeType.WEEKLY_A,
          isActive: dto.isActive ?? true,
        },
      });
    } catch (e) {
      throw this.mapPrismaError(e);
    }
  }

  async updateChallenge(id: number, dto: UpdateChallengeDto) {
    await this.getChallengeOrThrow(id);

    try {
      return await this.prisma.challenge.update({
        where: { id },
        data: {
          ...(dto.title !== undefined && { title: dto.title.trim() }),
          ...(dto.description !== undefined && {
            description: dto.description.trim(),
          }),
          ...(dto.date !== undefined && { date: new Date(dto.date) }),
          ...(dto.type !== undefined && { type: dto.type }),
          ...(dto.isActive !== undefined && { isActive: dto.isActive }),
        },
      });
    } catch (e) {
      throw this.mapPrismaError(e);
    }
  }

  async deleteChallenge(id: number) {
    await this.getChallengeOrThrow(id);

    // Les posts référencent le défi sans onDelete cascade : on refuse plutôt
    // que de laisser Prisma remonter une erreur de contrainte opaque.
    const posts = await this.prisma.post.count({ where: { challengeId: id } });
    if (posts > 0) {
      throw new ConflictException(
        'Ce défi contient des publications et ne peut pas être supprimé. Désactivez-le à la place.',
      );
    }

    await this.prisma.challenge.delete({ where: { id } });
    return { deleted: true };
  }

  private async getChallengeOrThrow(id: number) {
    const challenge = await this.prisma.challenge.findUnique({ where: { id } });
    if (!challenge) {
      throw new NotFoundException('Défi introuvable.');
    }
    if (challenge.conversationId !== null) {
      throw new ConflictException(
        "Ce défi appartient à un groupe et n'est pas administrable ici.",
      );
    }
    return challenge;
  }

  private mapPrismaError(e: unknown): Error {
    if (
      e instanceof Prisma.PrismaClientKnownRequestError &&
      e.code === 'P2002'
    ) {
      // @@unique([date, type, conversationId])
      return new ConflictException(
        'Un défi global existe déjà avec cette date et ce type.',
      );
    }
    return e instanceof Error ? e : new InternalServerErrorException(String(e));
  }
}

import {
  BadRequestException,
  ConflictException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import {
  ChallengeIdeaStatus,
  ChallengeType,
  PostModerationStatus,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateChallengeDto } from './dto/create-challenge.dto';
import { UpdateChallengeDto } from './dto/update-challenge.dto';
import * as fs from 'fs';
import * as path from 'path';
import { NotificationGateway } from '../bootstrap/notification.gateway';
import {
  ChallengeTranslationService,
  toTranslationsColumn,
} from '../translation/challenge-translation.service';
import {
  ChallengeLocale,
  ChallengeTranslations,
  isChallengeLocale,
} from '../translation/translation.constants';
import { UpdateChallengeTranslationDto } from './dto/update-challenge-translation.dto';

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationGateway: NotificationGateway,
    private readonly challengeTranslation: ChallengeTranslationService,
  ) {}

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
        ...(c.durationHours !== undefined && { durationHours: c.durationHours }),
        isActive: c.isActive !== undefined ? c.isActive : true,
      }));

      if (data.length === 0) return { imported: 0 };

      const res = await this.prisma.challenge.createMany({ data, skipDuplicates: true });
      // Traduction en arrière-plan : l'import ne doit pas attendre DeepL.
      void this.challengeTranslation.translateMissing().catch(() => undefined);
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
    const title = dto.title.trim();
    const description = dto.description?.trim() ?? '';
    // Ne lève jamais : sans DeepL, le défi est simplement créé sans traduction.
    const translations = await this.challengeTranslation.buildTranslations(
      title,
      description,
    );

    try {
      const challenge = await this.prisma.challenge.create({
        data: {
          title,
          description,
          translations: toTranslationsColumn(translations),
          date: dto.date ? new Date(dto.date) : new Date(),
          type: dto.type ?? ChallengeType.WEEKLY_A,
          durationHours: dto.endsAt ? null : dto.durationHours ?? null,
          endsAt: dto.endsAt ? new Date(dto.endsAt) : null,
          isActive: dto.isActive ?? true,
          latitude: dto.latitude ?? null,
          longitude: dto.longitude ?? null,
          icon: dto.icon ?? null,
        },
      });
      this.notificationGateway.broadcast('challengeCreated', {
        challengeId: challenge.id,
        challengeTitle: challenge.title,
        // L'app choisit le titre dans sa langue (cf. global_notification_service).
        challengeTranslations: challenge.translations,
        isGlobal: true,
      });
      return challenge;
    } catch (e) {
      throw this.mapPrismaError(e);
    }
  }

  async updateChallenge(id: number, dto: UpdateChallengeDto) {
    const existing = await this.getChallengeOrThrow(id);

    const title = dto.title?.trim() ?? existing.title;
    const description = dto.description?.trim() ?? existing.description;
    const textChanged =
      title !== existing.title || description !== existing.description;
    // On ne retraduit que si le texte français a changé (les corrections
    // manuelles sont conservées par buildTranslations).
    const translations = textChanged
      ? await this.challengeTranslation.buildTranslations(
          title,
          description,
          existing.translations as ChallengeTranslations | null,
        )
      : undefined;

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
          ...(dto.endsAt !== undefined && {
            endsAt: dto.endsAt ? new Date(dto.endsAt) : null,
            durationHours: null,
          }),
          ...(dto.durationHours !== undefined && dto.endsAt === undefined && {
            durationHours: dto.durationHours,
            endsAt: null,
          }),
          ...(dto.isActive !== undefined && { isActive: dto.isActive }),
          ...(dto.latitude !== undefined && { latitude: dto.latitude }),
          ...(dto.longitude !== undefined && { longitude: dto.longitude }),
          ...(dto.icon !== undefined && { icon: dto.icon }),
          ...(translations !== undefined && {
            translations: toTranslationsColumn(translations),
          }),
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

  async setManualTranslation(
    id: number,
    locale: string,
    dto: UpdateChallengeTranslationDto,
  ) {
    const challengeLocale = this.parseLocale(locale);
    const challenge = await this.getChallengeOrThrow(id);
    const translations: ChallengeTranslations = {
      ...((challenge.translations as ChallengeTranslations | null) ?? {}),
      [challengeLocale]: {
        title: dto.title.trim(),
        description: dto.description?.trim() ?? '',
        manual: true,
      },
    };
    return this.saveTranslations(id, translations);
  }

  async resetTranslation(id: number, locale: string) {
    const challengeLocale = this.parseLocale(locale);
    const challenge = await this.getChallengeOrThrow(id);
    const translations: ChallengeTranslations = {
      ...((challenge.translations as ChallengeTranslations | null) ?? {}),
    };
    delete translations[challengeLocale];

    // Si DeepL échoue, la langue retombe simplement sur le français.
    const automatic = await this.challengeTranslation.translateOne(
      challenge.title,
      challenge.description,
      challengeLocale,
    );
    if (automatic) translations[challengeLocale] = automatic;

    return this.saveTranslations(
      id,
      Object.keys(translations).length > 0 ? translations : null,
    );
  }

  private parseLocale(locale: string): ChallengeLocale {
    if (!isChallengeLocale(locale)) {
      throw new BadRequestException(`Langue de traduction inconnue : ${locale}`);
    }
    return locale;
  }

  private saveTranslations(
    id: number,
    translations: ChallengeTranslations | null,
  ) {
    return this.prisma.challenge.update({
      where: { id },
      data: { translations: toTranslationsColumn(translations) },
      include: { _count: { select: { posts: true } } },
    });
  }

  async listChallengeIdeas() {
    return this.prisma.challengeIdea.findMany({
      orderBy: { createdAt: 'desc' },
      include: { user: { select: { username: true } } },
    });
  }

  async listReportedPosts() {
    return this.prisma.post.findMany({
      where: { reports: { some: {} } },
      orderBy: [{ reports: { _count: 'desc' } }, { createdAt: 'desc' }],
      include: {
        user: { select: { id: true, username: true, avatarUrl: true, avatarKey: true } },
        challenge: { select: { id: true, title: true, type: true } },
        _count: { select: { reports: true, upVotes: true } },
      },
    });
  }

  async restorePost(id: number) {
    const post = await this.prisma.post.findUnique({ where: { id } });
    if (!post) throw new NotFoundException('Post introuvable.');
    return this.prisma.post.update({
      where: { id },
      data: {
        isGhosted: false,
        moderationStatus: PostModerationStatus.APPROVED,
      },
    });
  }

  async deletePost(id: number) {
    const post = await this.prisma.post.findUnique({ where: { id } });
    if (!post) throw new NotFoundException('Post introuvable.');
    return this.prisma.post.update({
      where: { id },
      data: {
        isGhosted: true,
        moderationStatus: PostModerationStatus.REMOVED,
      },
    });
  }

  async listReportedUsers() {
    const users = await this.prisma.user.findMany({
      where: {
        role: 'USER',
        posts: { some: { reports: { some: {} } } },
      },
      select: {
        id: true,
        username: true,
        avatarUrl: true,
        avatarKey: true,
        isBanned: true,
        banReason: true,
        bannedAt: true,
        posts: { select: { _count: { select: { reports: true } } } },
      },
    });

    return users
      .map(({ posts, ...user }) => ({
        ...user,
        reportCount: posts.reduce((total, post) => total + post._count.reports, 0),
      }))
      .sort((a, b) => b.reportCount - a.reportCount);
  }

  async banUser(id: number, reason?: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: { id: true, role: true },
    });
    if (!user) throw new NotFoundException('Utilisateur introuvable.');
    if (user.role === 'ADMIN') {
      throw new ConflictException('Un administrateur ne peut pas être banni.');
    }

    const bannedUser = await this.prisma.user.update({
      where: { id },
      data: {
        isBanned: true,
        banReason: reason?.trim() || null,
        bannedAt: new Date(),
      },
      select: {
        id: true,
        username: true,
        isBanned: true,
        banReason: true,
        bannedAt: true,
      },
    });

    this.notificationGateway.sendToUser(id, 'userBanned', {
      reason: bannedUser.banReason,
    });

    return bannedUser;
  }

  async unbanUser(id: number) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('Utilisateur introuvable.');
    return this.prisma.user.update({
      where: { id },
      data: { isBanned: false, banReason: null, bannedAt: null },
      select: {
        id: true,
        username: true,
        isBanned: true,
        banReason: true,
        bannedAt: true,
      },
    });
  }

  async updateChallengeIdeaStatus(id: number, status: ChallengeIdeaStatus) {
    const idea = await this.prisma.challengeIdea.findUnique({ where: { id } });
    if (!idea) throw new NotFoundException('Idée de défi introuvable.');

    return this.prisma.challengeIdea.update({
      where: { id },
      data: { status },
      include: { user: { select: { username: true } } },
    });
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

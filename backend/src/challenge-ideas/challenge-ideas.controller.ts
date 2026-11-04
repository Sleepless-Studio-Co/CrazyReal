import {
  BadRequestException,
  Body,
  Controller,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { ValidatedUser } from '../auth/interfaces/auth-user.interface';
import { PrismaService } from '../prisma/prisma.service';
import { CreateChallengeIdeaDto } from './dto/create-challenge-idea.dto';

@ApiTags('Challenge ideas')
@ApiBearerAuth('access-token')
@Controller('challenge-ideas')
@UseGuards(JwtAuthGuard)
export class ChallengeIdeasController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  async create(
    @CurrentUser() user: ValidatedUser,
    @Body() dto: CreateChallengeIdeaDto,
  ) {
    const content = dto.content.trim();
    if (content.length < 3) {
      throw new BadRequestException(
        'L’idée doit contenir au moins 3 caractères.',
      );
    }

    return this.prisma.challengeIdea.create({
      data: {
        content,
        userId: user.userId,
      },
      select: {
        id: true,
        content: true,
        createdAt: true,
      },
    });
  }
}

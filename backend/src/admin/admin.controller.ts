import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { AdminService } from './admin.service';
import { AdminGuard } from '../auth/admin.guard';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateChallengeDto } from './dto/create-challenge.dto';
import { UpdateChallengeDto } from './dto/update-challenge.dto';
import { UpdateChallengeIdeaStatusDto } from './dto/update-challenge-idea-status.dto';
import { UpdateChallengeTranslationDto } from './dto/update-challenge-translation.dto';

@Controller('admin')
@UseGuards(JwtAuthGuard, AdminGuard)
@ApiBearerAuth('access-token')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Post('import-challenges')
  @ApiOperation({ summary: 'Importer les défis depuis prisma/challenges.json' })
  async importChallenges() {
    return this.adminService.importChallengesFromFile();
  }

  @Get('challenges')
  @ApiOperation({ summary: 'Lister les défis globaux' })
  async listChallenges() {
    return this.adminService.listChallenges();
  }

  @Post('challenges')
  @ApiOperation({ summary: 'Créer un défi global' })
  async createChallenge(@Body() dto: CreateChallengeDto) {
    return this.adminService.createChallenge(dto);
  }

  @Patch('challenges/:id')
  @ApiOperation({ summary: 'Modifier un défi global' })
  async updateChallenge(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateChallengeDto,
  ) {
    return this.adminService.updateChallenge(id, dto);
  }

  @Delete('challenges/:id')
  @ApiOperation({ summary: 'Supprimer un défi global' })
  async deleteChallenge(@Param('id', ParseIntPipe) id: number) {
    return this.adminService.deleteChallenge(id);
  }

  @Put('challenges/:id/translations/:locale')
  @ApiOperation({
    summary:
      'Corriger à la main la traduction d’un défi (jamais écrasée par DeepL)',
  })
  async setChallengeTranslation(
    @Param('id', ParseIntPipe) id: number,
    @Param('locale') locale: string,
    @Body() dto: UpdateChallengeTranslationDto,
  ) {
    return this.adminService.setManualTranslation(id, locale, dto);
  }

  @Delete('challenges/:id/translations/:locale')
  @ApiOperation({
    summary: 'Abandonner la correction manuelle et retraduire avec DeepL',
  })
  async resetChallengeTranslation(
    @Param('id', ParseIntPipe) id: number,
    @Param('locale') locale: string,
  ) {
    return this.adminService.resetTranslation(id, locale);
  }

  @Get('challenge-ideas')
  @ApiOperation({ summary: 'Lister les idées de défis' })
  async listChallengeIdeas() {
    return this.adminService.listChallengeIdeas();
  }

  @Patch('challenge-ideas/:id/status')
  @ApiOperation({ summary: 'Modifier le statut d’une idée de défi' })
  async updateChallengeIdeaStatus(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateChallengeIdeaStatusDto,
  ) {
    return this.adminService.updateChallengeIdeaStatus(id, dto.status);
  }
}

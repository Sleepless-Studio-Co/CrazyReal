import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { AdminService } from './admin.service';
import { AdminGuard } from '../auth/admin.guard';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateChallengeDto } from './dto/create-challenge.dto';
import { UpdateChallengeDto } from './dto/update-challenge.dto';

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
}

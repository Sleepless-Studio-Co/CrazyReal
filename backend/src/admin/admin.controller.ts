import { Controller, Post, Get, UseGuards } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminGuard } from '../auth/admin.guard';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('admin')
@UseGuards(JwtAuthGuard, AdminGuard)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Post('import-challenges')
  async importChallenges() {
    return this.adminService.importChallengesFromFile();
  }

  @Get('challenges')
  async listChallenges() {
    return this.adminService.listChallenges();
  }
}

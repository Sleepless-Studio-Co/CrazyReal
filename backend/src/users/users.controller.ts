import { Controller, Get, Param, UseGuards, ForbiddenException, ParseIntPipe } from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { ApiBearerAuth } from '@nestjs/swagger';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: any) {
    const authenticatedUserId = user.userId;

    if (id !== authenticatedUserId) {
      throw new ForbiddenException('You can only access your own profile');
    }

    return this.usersService.findById(id);
  }
}

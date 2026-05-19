import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { ValidatedUser } from '../auth/interfaces/auth-user.interface';

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

  @Patch('me/avatar')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Update the base avatar selection' })
  @ApiResponse({ status: 200, description: 'Avatar updated successfully' })
  async updateAvatarKey(
    @CurrentUser() user: ValidatedUser,
    @Body() body: { avatarKey?: string | null },
  ) {
    const avatarKey = body.avatarKey ?? null;
    const updatedUser = await this.usersService.updateAvatar(user.userId, {
      avatarKey,
      avatarUrl: null,
    });

    return { user: updatedUser };
  }

  @Post('me/avatar')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Upload a custom avatar image' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: {
          type: 'string',
          format: 'binary',
        },
      },
    },
  })
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: './uploads',
        filename: (req, file, callback) => {
          const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
          const ext = extname(file.originalname);
          callback(null, `avatar-${uniqueSuffix}${ext}`);
        },
      }),
    }),
  )
  async uploadAvatar(
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: ValidatedUser,
  ) {
    const avatarUrl = `/uploads/${file.filename}`;

    const updatedUser = await this.usersService.updateAvatar(user.userId, {
      avatarUrl,
      avatarKey: null,
    });

    return { user: updatedUser };
  }

  @Delete('me/avatar')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Remove avatar information' })
  async clearAvatar(@CurrentUser() user: ValidatedUser) {
    const updatedUser = await this.usersService.updateAvatar(user.userId, {
      avatarUrl: null,
      avatarKey: null,
    });

    return { user: updatedUser };
  }
}

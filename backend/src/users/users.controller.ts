import {
  BadRequestException,
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
import { promises as fs } from 'fs';
import { diskStorage } from 'multer';
import { basename, extname, join } from 'path';
import {
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiOperation,
  ApiResponse,
} from '@nestjs/swagger';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { ValidatedUser } from '../auth/interfaces/auth-user.interface';

const BASE_AVATAR_KEYS = new Set([
  'ember',
  'sea',
  'citrus',
  'berry',
  'noon',
  'terra',
]);

const ALLOWED_AVATAR_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
]);

const ALLOWED_AVATAR_EXTENSIONS = new Set([
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.gif',
]);

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  findOne(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: ValidatedUser,
  ) {
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
    const avatarKey = body.avatarKey;

    if (avatarKey == null || avatarKey.trim() === '') {
      throw new BadRequestException('avatarKey is required');
    }

    if (!BASE_AVATAR_KEYS.has(avatarKey)) {
      throw new BadRequestException(
        `Invalid avatarKey. Allowed values: ${Array.from(BASE_AVATAR_KEYS).join(', ')}`,
      );
    }

    const previousAvatarUrl = user.avatarUrl;

    const updatedUser = await this.usersService.updateAvatar(user.userId, {
      avatarKey,
      avatarUrl: null,
    });

    await this.deleteStoredAvatar(previousAvatarUrl);

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
          const uniqueSuffix =
            Date.now() + '-' + Math.round(Math.random() * 1e9);
          const ext = extname(file.originalname);
          callback(null, `avatar-${uniqueSuffix}${ext}`);
        },
      }),
      fileFilter: (_req, file, callback) => {
        const ext = extname(file.originalname).toLowerCase();

        if (
          !ALLOWED_AVATAR_MIME_TYPES.has(file.mimetype) ||
          !ALLOWED_AVATAR_EXTENSIONS.has(ext)
        ) {
          callback(
            new BadRequestException(
              'Only JPEG, PNG, WebP, and GIF avatar images are allowed',
            ),
            false,
          );
          return;
        }

        callback(null, true);
      },
      limits: {
        fileSize: 5 * 1024 * 1024,
      },
    }),
  )
  async uploadAvatar(
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: ValidatedUser,
  ) {
    if (!file) {
      throw new BadRequestException('Avatar file is required');
    }

    const avatarUrl = `/uploads/${file.filename}`;
    const previousAvatarUrl = user.avatarUrl;

    const updatedUser = await this.usersService.updateAvatar(user.userId, {
      avatarUrl,
      avatarKey: null,
    });

    await this.deleteStoredAvatar(previousAvatarUrl);

    return { user: updatedUser };
  }

  @Delete('me/avatar')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Remove avatar information' })
  async clearAvatar(@CurrentUser() user: ValidatedUser) {
    const previousAvatarUrl = user.avatarUrl;

    const updatedUser = await this.usersService.updateAvatar(user.userId, {
      avatarUrl: null,
      avatarKey: null,
    });

    await this.deleteStoredAvatar(previousAvatarUrl);

    return { user: updatedUser };
  }

  private async deleteStoredAvatar(avatarUrl?: string | null) {
    if (!avatarUrl || !avatarUrl.startsWith('/uploads/')) {
      return;
    }

    const fileName = basename(avatarUrl);
    const filePath = join(process.cwd(), 'uploads', fileName);

    try {
      await fs.unlink(filePath);
    } catch (error) {
      if (
        typeof error === 'object' &&
        error !== null &&
        'code' in error &&
        (error as { code?: string }).code === 'ENOENT'
      ) {
        return;
      }
    }
  }
}

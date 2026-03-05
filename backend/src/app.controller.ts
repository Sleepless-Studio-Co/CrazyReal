import { Controller, Get, Post, UploadedFile, UseInterceptors, UseGuards, Param } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiResponse, ApiConsumes, ApiBody } from '@nestjs/swagger';
import { PrismaService } from './prisma/prisma.service';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { readdirSync } from 'fs';
import { join } from 'path';
import { I18n, I18nContext } from 'nestjs-i18n';
import { JwtAuthGuard } from './auth/jwt-auth.guard';
import { CurrentUser } from './auth/current-user.decorator';

@ApiTags('CrazyReal')
@Controller()
export class AppController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('challenge/current')
  @ApiOperation({ summary: 'Récupérer le challenge actuel' })
  @ApiResponse({ status: 200, description: 'Challenge récupéré avec succès' })
  async getCurrentChallenge(@I18n() i18n: I18nContext) {
    let challenge = await this.prisma.challenge.findUnique({ where: { id: 1 } });
    if (!challenge) {
      challenge = await this.prisma.challenge.create({
        data: { id: 1, content: "Fais une grimace ! 🤪", isActive: true },
      });
    }
    return challenge;
  }

  @Post('posts')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Upload une photo pour le challenge' })
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
  @ApiResponse({ status: 201, description: 'Photo uploadée avec succès' })
  @UseInterceptors(FileInterceptor('file', {
    storage: diskStorage({
      destination: './uploads',
      filename: (req, file, callback) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = extname(file.originalname);
        callback(null, `image-${uniqueSuffix}${ext}`);
      },
    }),
  }))
  async uploadPhoto(@UploadedFile() file: Express.Multer.File, @CurrentUser() user: any, @I18n() i18n: I18nContext) {
    console.log(await i18n.t('common.loading'), file.filename);

    const apiHost = process.env.API_HOST || 'localhost';
    const apiPort = process.env.API_PORT || '3000';

    const post = await this.prisma.post.create({
      data: {
        photoUrl: `http://${apiHost}:${apiPort}/uploads/${file.filename}`,
        challengeId: 1,
        userId: user.userId,
      },
    });

    return post;
  }

  @Get('uploads')
  async getUploads() {
    const uploadsDir = join(process.cwd(), 'uploads');
    const files = readdirSync(uploadsDir);
    const apiHost = process.env.API_HOST || 'localhost';
    const apiPort = process.env.API_PORT || '3000';
    return { files: files.map(file => `http://${apiHost}:${apiPort}/uploads/${file}`) };
  }

  @Get('posts')
  @ApiOperation({ summary: 'Récupérer tous les posts avec les utilisateurs' })
  @ApiResponse({ status: 200, description: 'Posts récupérés avec succès' })
  async getPosts() {
    const posts = await this.prisma.post.findMany({
      include: {
        user: {
          select: {
            username: true,
          },
        },
      },
    });
    return posts;
  }

  @Get('posts/:id')
  @ApiOperation({ summary: 'Récupérer un post par ID' })
  @ApiResponse({ status: 200, description: 'Post récupéré avec succès' })
  async getPost(@Param('id') id: string) {
    const post = await this.prisma.post.findUnique({
      where: { id: parseInt(id) },
      include: {
        user: {
          select: {
            username: true,
          },
        },
      },
    });
    return post;
  }
}

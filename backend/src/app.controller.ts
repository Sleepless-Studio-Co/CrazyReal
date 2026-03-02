import { Controller, Get, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiResponse, ApiConsumes, ApiBody } from '@nestjs/swagger';
import { PrismaService } from './prisma/prisma.service';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { readdirSync } from 'fs';
import { join } from 'path';

@ApiTags('CrazyReal')
@Controller()
export class AppController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('challenge/current')
  @ApiOperation({ summary: 'Récupérer le challenge actuel' })
  @ApiResponse({ status: 200, description: 'Challenge récupéré avec succès' })
  async getCurrentChallenge() {
    let challenge = await this.prisma.challenge.findUnique({ where: { id: 1 } });
    if (!challenge) {
      challenge = await this.prisma.challenge.create({
        data: { id: 1, content: "Fais une grimace ! 🤪", isActive: true },
      });
    }
    return challenge;
  }

  @Post('posts')
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
  async uploadPhoto(@UploadedFile() file: Express.Multer.File) {
    console.log("Fichier reçu :", file.filename);

    const apiHost = process.env.API_HOST || 'localhost';
    const apiPort = process.env.API_PORT || '3000';

    const post = await this.prisma.post.create({
      data: {
        photoUrl: `http://${apiHost}:${apiPort}/uploads/${file.filename}`,
        challengeId: 1,
        userId: 1,
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
}

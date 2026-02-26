import { Controller, Get, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { PrismaClient } from '@prisma/client';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { readdirSync } from 'fs';
import { join } from 'path';

const prisma = new PrismaClient();

@Controller()
export class AppController {

  @Get('challenge/current')
  async getCurrentChallenge() {
    let challenge = await prisma.challenge.findUnique({ where: { id: 1 } });
    if (!challenge) {
      challenge = await prisma.challenge.create({
        data: { id: 1, content: "Fais une grimace ! 🤪", isActive: true },
      });
    }
    return challenge;
  }

  @Post('posts')
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
    
    const post = await prisma.post.create({
      data: {
        photoUrl: `http://${apiHost}:${apiPort}/uploads/${file.filename}`,
        challengeId: 1,
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
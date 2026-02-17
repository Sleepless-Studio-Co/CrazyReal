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

  // --- Partie 1 : Récupérer le défi (Déjà fait) ---
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

  // --- Partie 2 : Uploader une photo (NOUVEAU) ---
  @Post('posts')
  @UseInterceptors(FileInterceptor('file', {
    storage: diskStorage({
      destination: './uploads', // On enregistre dans ce dossier
      filename: (req, file, callback) => {
        // On génère un nom unique (ex: image-123456789.jpg)
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = extname(file.originalname);
        callback(null, `image-${uniqueSuffix}${ext}`);
      },
    }),
  }))
  async uploadPhoto(@UploadedFile() file: Express.Multer.File) {
    console.log("Fichier reçu :", file.filename);

    // On crée le post dans la base de données
    // (Assure-toi que ton Challenge n°1 existe bien)
    const post = await prisma.post.create({
      data: {
        photoUrl: `http://localhost:3000/uploads/${file.filename}`, // L'URL locale
        challengeId: 1, // On lie ça au défi n°1 pour le test
      },
    });

    return post;
  }

  // --- Partie 3 : Lister les photos uploadées ---
  @Get('uploads')
  async getUploads() {
    const uploadsDir = join(process.cwd(), 'uploads');
    const files = readdirSync(uploadsDir);
    return { files: files.map(file => `http://10.0.2.2:3000/uploads/${file}`) }; // Utilise 10.0.2.2 pour l'émulateur Android
  }
}
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function createDefaultUser() {
  const existingUser = await prisma.user.findUnique({
    where: { email: 'crazyadmin' },
  });

  if (!existingUser) {
    const hashedPassword = await bcrypt.hash('crazyadmin', 10);
    await prisma.user.create({
      data: {
        email: 'crazyadmin',
        password: hashedPassword,
        username: 'crazyadmin',
      },
    });
    console.log('Utilisateur par défaut créé : crazyadmin / crazyadmin');
  } else {
    console.log('Utilisateur crazyadmin existe déjà');
  }
}

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  app.useStaticAssets(join(__dirname, '..', 'uploads'), {
    prefix: '/uploads/',
  });

  // Créer l'utilisateur par défaut au démarrage
  await createDefaultUser();

  await app.listen(3000, '0.0.0.0');
  console.log('🚀 API démarrée sur http://0.0.0.0:3000');
}
bootstrap();

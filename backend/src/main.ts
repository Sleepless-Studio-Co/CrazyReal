import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';

async function bootstrap() {
  // On précise qu'on utilise Express explicitement
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // LA LIGNE MAGIQUE : On rend le dossier /uploads accessible publiquement
  app.useStaticAssets(join(__dirname, '..', 'uploads'), {
    prefix: '/uploads/',
  });

  await app.listen(3000);
}
bootstrap();
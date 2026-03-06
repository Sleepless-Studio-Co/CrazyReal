import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { NestExpressApplication } from '@nestjs/platform-express';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { join } from 'path';
import { AdminBootstrapService } from './bootstrap/admin-bootstrap.service';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  app.enableCors({
    origin: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });

  const config = new DocumentBuilder()
    .setTitle('CrazyReal API')
    .setDescription('The CrazyReal API documentation')
    .setVersion('1.0')
    .addTag('crazyreal')
    .build();
  const documentFactory = () => SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api', app, documentFactory);

  app.useStaticAssets(join(__dirname, '..', 'uploads'), {
    prefix: '/uploads/',
  });

  const adminBootstrapService = app.get(AdminBootstrapService);

  try {
    await adminBootstrapService.createDefaultUser();
  } catch (error) {
    console.warn('Admin bootstrap failed on startup.');
  }

  await app.listen(3000, '0.0.0.0');
  console.log('🚀 API démarrée sur http://0.0.0.0:3000');
}
bootstrap();

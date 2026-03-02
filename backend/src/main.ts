import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { NestExpressApplication } from '@nestjs/platform-express';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { join } from 'path';
import { PrismaService } from './prisma/prisma.service';
import * as bcrypt from 'bcrypt';

async function createDefaultUser(prisma: PrismaService) {
  const shouldBootstrapAdmin = process.env.BOOTSTRAP_ADMIN === 'true';
  if (!shouldBootstrapAdmin) {
    return;
  }

  const adminEmail = process.env.BOOTSTRAP_ADMIN_EMAIL;
  const adminPassword = process.env.BOOTSTRAP_ADMIN_PASSWORD;
  const adminUsername = process.env.BOOTSTRAP_ADMIN_USERNAME ?? 'admin';

  if (!adminEmail || !adminPassword) {
    throw new Error(
      'BOOTSTRAP_ADMIN=true requires BOOTSTRAP_ADMIN_EMAIL and BOOTSTRAP_ADMIN_PASSWORD',
    );
  }

  const existingUser = await prisma.user.findUnique({
    where: { email: adminEmail },
  });

  if (!existingUser) {
    const hashedPassword = await bcrypt.hash(adminPassword, 12);
    await prisma.user.create({
      data: {
        email: adminEmail,
        password: hashedPassword,
        username: adminUsername,
      },
    });
    console.log(`Admin bootstrap user created: ${adminEmail}`);
  } else {
    console.log(`Admin bootstrap user already exists: ${adminEmail}`);
  }
}

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

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

  const prisma = app.get(PrismaService);

  try {
    await createDefaultUser(prisma);
  } catch (error) {
    console.warn('Admin bootstrap failed on startup:', error);
  }

  await app.listen(3000, '0.0.0.0');
  console.log('🚀 API démarrée sur http://0.0.0.0:3000');
}
bootstrap();

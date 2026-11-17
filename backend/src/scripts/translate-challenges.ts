/**
 * Traduit les défis globaux qui n'ont encore aucune traduction.
 * Usage : npm run translate:challenges  (depuis backend/, avec API_TRADUCTION dans .env)
 */
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { PrismaModule } from '../prisma/prisma.module';
import { ChallengeTranslationService } from '../translation/challenge-translation.service';
import { DeepLService } from '../translation/deepl.service';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }), PrismaModule],
  providers: [DeepLService, ChallengeTranslationService],
})
class TranslateChallengesModule {}

async function main() {
  const app = await NestFactory.createApplicationContext(TranslateChallengesModule);
  try {
    const count = await app.get(ChallengeTranslationService).translateMissing();
    console.log(`${count} défi(s) traduit(s).`);
  } finally {
    await app.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

import { Global, Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { PrismaModule } from '../prisma/prisma.module';
import { ChallengeLocaleInterceptor } from './challenge-locale.interceptor';
import { ChallengeTranslationService } from './challenge-translation.service';
import { DeepLService } from './deepl.service';

@Global()
@Module({
  imports: [PrismaModule],
  providers: [
    DeepLService,
    ChallengeTranslationService,
    { provide: APP_INTERCEPTOR, useClass: ChallengeLocaleInterceptor },
  ],
  exports: [DeepLService, ChallengeTranslationService],
})
export class TranslationModule {}

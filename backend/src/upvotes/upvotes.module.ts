import { Module } from '@nestjs/common';
import { UpVotesService } from './upvotes.service';
import { UpVotesController } from './upvotes.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [UpVotesController],
  providers: [UpVotesService],
})
export class UpVotesModule {}

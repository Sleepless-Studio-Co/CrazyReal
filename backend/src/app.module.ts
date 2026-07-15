import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';
import { PrismaModule } from './prisma/prisma.module';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { AdminBootstrapService } from './bootstrap/admin-bootstrap.service';
import { FriendsModule } from './friends/friends.module';
import { ChatModule } from './chat/chat.module';
import { FeedModule } from './feed/feed.module';
import { UpVotesModule } from './upvotes/upvotes.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    PrismaModule,
    ThrottlerModule.forRoot([
      {
        ttl: 60000,
        limit: 60,
      },
    ]),
    UsersModule,
    AuthModule,
    FriendsModule,
    ChatModule,
    FeedModule,
    UpVotesModule,
  ],
  controllers: [AppController],
  providers: [
    AdminBootstrapService,
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}

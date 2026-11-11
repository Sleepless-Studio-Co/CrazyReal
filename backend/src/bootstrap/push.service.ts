import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';
import { PrismaService } from '../prisma/prisma.service';

type PushChannel = 'friend_requests' | 'challenges' | 'general';

@Injectable()
export class PushService implements OnModuleInit {
  private readonly logger = new Logger(PushService.name);
  private app?: admin.app.App;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  onModuleInit() {
    const raw = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT');
    if (!raw) {
      this.logger.warn(
        'FIREBASE_SERVICE_ACCOUNT is not configured; push is disabled',
      );
      return;
    }

    try {
      this.app =
        admin.apps[0] ??
        admin.initializeApp({
          credential: admin.credential.cert(JSON.parse(raw)),
        });
    } catch (error) {
      this.logger.error('Unable to initialize Firebase Admin', error);
    }
  }

  async sendToUsers(
    userIds: number[],
    title: string,
    body: string,
    channelId: PushChannel,
    data: Record<string, string> = {},
  ): Promise<boolean> {
    if (!this.app || userIds.length === 0) return false;
    try {
      const devices = await this.prisma.deviceToken.findMany({
        where: { userId: { in: [...new Set(userIds)] } },
        select: { id: true, token: true },
      });
      let delivered = devices.length === 0;
      for (let offset = 0; offset < devices.length; offset += 500) {
        delivered =
          (await this.sendBatch(
          devices.slice(offset, offset + 500),
          title,
          body,
          channelId,
          data,
          )) || delivered;
      }
      return delivered;
    } catch (error) {
      this.logger.error('Unable to send push notification', error);
      return false;
    }
  }

  async sendToTopic(
    topic: string,
    title: string,
    body: string,
    channelId: PushChannel,
    data: Record<string, string> = {},
  ) {
    if (!this.app) return;
    try {
      await admin.messaging(this.app).send({
        topic,
        notification: { title, body },
        data,
        android: { notification: { channelId } },
      });
    } catch (error) {
      this.logger.error(
        `Unable to send push topic notification to ${topic}`,
        error,
      );
    }
  }

  private async sendBatch(
    devices: { id: number; token: string }[],
    title: string,
    body: string,
    channelId: PushChannel,
    data: Record<string, string>,
  ): Promise<boolean> {
    if (devices.length === 0) return false;
    let response: admin.messaging.BatchResponse | undefined;
    let lastError: unknown;
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        response = await admin.messaging(this.app!).sendEachForMulticast({
          tokens: devices.map((device) => device.token),
          notification: { title, body },
          data,
          android: { notification: { channelId } },
        });
        break;
      } catch (error) {
        lastError = error;
        if (attempt < 2) {
          await new Promise((resolve) => setTimeout(resolve, 500 * 2 ** attempt));
        }
      }
    }
    if (!response) {
      throw lastError;
    }

    this.logger.log(
      `Push ${channelId}: ${response.successCount} delivered, ${response.failureCount} failed`,
    );
    const invalidIds = response.responses
      .map((result, index) => {
        const code = result.error?.code;
        return code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token'
          ? devices[index].id
          : null;
      })
      .filter((id): id is number => id !== null);
    if (invalidIds.length > 0) {
      await this.prisma.deviceToken.deleteMany({
        where: { id: { in: invalidIds } },
      });
    }
    return response.successCount > 0;
  }
}

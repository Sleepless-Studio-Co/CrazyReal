import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Socket } from 'socket.io';
import { JWT_CONFIG_KEYS } from './jwt.config';
import type { JwtPayload } from './interfaces/jwt-payload.interface';
import type { ValidatedUser } from './interfaces/auth-user.interface';

@Injectable()
export class WsJwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const client = context.switchToWs().getClient<Socket>();
    const token = this.extractToken(client);

    if (!token) {
      console.warn(`[ws-auth] Connexion WebSocket ${client.id} refusée : aucun token fourni.`);
      throw new UnauthorizedException('Token manquant pour la connexion WebSocket.');
    }

    try {
      const payload = await this.jwtService.verifyAsync<JwtPayload>(token, {
        secret: this.configService.getOrThrow<string>(JWT_CONFIG_KEYS.secret),
      });

      const user: ValidatedUser = {
        userId: payload.sub,
        email: payload.email,
        username: payload.username,
      };

      client.data.user = user;
      return true;
    } catch (error) {
      console.warn(`[ws-auth] Connexion WebSocket ${client.id} refusée : token invalide ou expiré.`, error);
      throw new UnauthorizedException('Token WebSocket invalide ou expiré.');
    }
  }

  private extractToken(client: Socket): string | null {
    const authHeader = client.handshake.headers?.authorization;
    if (typeof authHeader === 'string' && authHeader.startsWith('Bearer ')) {
      return authHeader.slice(7);
    }

    const authToken = client.handshake.auth?.token;
    if (typeof authToken === 'string' && authToken.startsWith('Bearer ')) {
      return authToken.slice(7);
    }

    if (typeof authToken === 'string') {
      return authToken;
    }

    return null;
  }
}

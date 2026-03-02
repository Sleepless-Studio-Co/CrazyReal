import { Test, TestingModule } from '@nestjs/testing';
import {
  CanActivate,
  ConflictException,
  ExecutionContext,
  INestApplication,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AuthController } from '../src/auth/auth.controller';
import { AuthService } from '../src/auth/auth.service';
import { JwtAuthGuard } from '../src/auth/jwt-auth.guard';

@Injectable()
class TestJwtAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<{ headers: { authorization?: string }; user?: unknown }>();
    const authHeader = request.headers.authorization;

    if (authHeader === 'Bearer valid-token') {
      request.user = {
        userId: 1,
        email: 'john@example.com',
        username: 'john',
      };
      return true;
    }

    throw new UnauthorizedException('Unauthorized');
  }
}

describe('AuthController (e2e)', () => {
  let app: INestApplication<App>;
  let authServiceMock: {
    register: jest.Mock;
    login: jest.Mock;
    refresh: jest.Mock;
    revokeRefreshToken: jest.Mock;
  };

  beforeEach(async () => {
    authServiceMock = {
      register: jest.fn(),
      login: jest.fn(),
      refresh: jest.fn(),
      revokeRefreshToken: jest.fn(),
    };

    const moduleFixture: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [
        {
          provide: AuthService,
          useValue: authServiceMock,
        },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useClass(TestJwtAuthGuard)
      .compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  it('POST /auth/register should register a user successfully', async () => {
    authServiceMock.register.mockResolvedValue({
      access_token: 'access-token',
      refresh_token: 'refresh-token',
      user: {
        id: 1,
        email: 'john@example.com',
        username: 'john',
      },
    });

    await request(app.getHttpServer())
      .post('/auth/register')
      .send({
        email: 'john@example.com',
        password: 'StrongPassword123!',
        username: 'john',
      })
      .expect(201)
      .expect(({ body }) => {
        expect(body.access_token).toBe('access-token');
        expect(body.user.email).toBe('john@example.com');
      });

    expect(authServiceMock.register).toHaveBeenCalledWith(
      'john@example.com',
      'StrongPassword123!',
      'john',
    );
  });

  it('POST /auth/register should return proper error response on duplicate email', async () => {
    authServiceMock.register.mockRejectedValue(new ConflictException('mail already in use'));

    await request(app.getHttpServer())
      .post('/auth/register')
      .send({
        email: 'john@example.com',
        password: 'StrongPassword123!',
        username: 'john',
      })
      .expect(409)
      .expect(({ body }) => {
        expect(body.message).toBe('mail already in use');
      });
  });

  it('POST /auth/login should authenticate with valid credentials', async () => {
    authServiceMock.login.mockResolvedValue({
      access_token: 'access-token',
      refresh_token: 'refresh-token',
      user: {
        id: 1,
        email: 'john@example.com',
        username: 'john',
      },
    });

    await request(app.getHttpServer())
      .post('/auth/login')
      .send({
        email: 'john@example.com',
        password: 'StrongPassword123!',
      })
      .expect(201)
      .expect(({ body }) => {
        expect(body.access_token).toBe('access-token');
        expect(body.user.username).toBe('john');
      });

    expect(authServiceMock.login).toHaveBeenCalledWith('john@example.com', 'StrongPassword123!');
  });

  it('POST /auth/login should fail with invalid credentials', async () => {
    authServiceMock.login.mockRejectedValue(
      new UnauthorizedException('Email ou mot de passe incorrect'),
    );

    await request(app.getHttpServer())
      .post('/auth/login')
      .send({
        email: 'john@example.com',
        password: 'wrong-password',
      })
      .expect(401)
      .expect(({ body }) => {
        expect(body.message).toBe('Email ou mot de passe incorrect');
      });
  });

  it('GET /auth/me should return current user with valid JWT', async () => {
    await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', 'Bearer valid-token')
      .expect(200)
      .expect(({ body }) => {
        expect(body).toEqual({
          userId: 1,
          email: 'john@example.com',
          username: 'john',
        });
      });
  });

  it('GET /auth/me should return proper error response without JWT', async () => {
    await request(app.getHttpServer())
      .get('/auth/me')
      .expect(401)
      .expect(({ body }) => {
        expect(body.message).toBe('Unauthorized');
      });
  });
});

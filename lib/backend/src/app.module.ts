// src/app.module.ts
import { Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { CacheModule } from '@nestjs/cache-manager';
import { redisStore } from 'cache-manager-ioredis-yet';
import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';
import { LoggerModule } from 'nestjs-pino';
import { ThrottlerModule } from '@nestjs/throttler';
import { ScheduleModule } from '@nestjs/schedule';

// Modules internes
import { ConfigModule } from './config/config.module';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ProvidersModule } from './providers/providers.module';
import { PetsModule } from './pets/pets.module';
import { BookingsModule } from './bookings/bookings.module';
import { ReviewsModule } from './reviews/reviews.module';
import { HealthModule } from './health/health.module';
import { UploadsModule } from './uploads/uploads.module';
import { PatientsModule } from './patients/patients.module';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';
import { MapsModule } from './maps/maps.module';
import { EarningsModule } from './earnings/earnings.module';
import { AdoptModule } from './adopt/adopt.module';
import { PetshopModule } from './petshop/petshop.module';
import { NotificationsModule } from './notifications/notifications.module';



@Module({
  imports: [
    // Fichiers statiques /public
    ServeStaticModule.forRoot({
      rootPath: join(process.cwd(), 'public'),
      serveRoot: '/',
    }),

    // Logger pino
    LoggerModule.forRootAsync({
      useFactory: () => {
        const pinoHttp: any = {
          level: process.env.LOG_LEVEL || 'info',
          redact: ['req.headers.authorization'],
        };
        if (process.env.NODE_ENV !== 'production') {
          try {
            require.resolve('pino-pretty');
            pinoHttp.transport = {
              target: 'pino-pretty',
              options: { translateTime: 'SYS:standard', ignore: 'pid,hostname' },
            };
          } catch {}
        }
        return { pinoHttp };
      },
    }),

    // Rate limit
    ThrottlerModule.forRoot([{ ttl: 60, limit: 120 }]),

    // Cron
    ScheduleModule.forRoot(),

    // Cache Redis (fallback mémoire si REDIS_URL absent)
    CacheModule.registerAsync({
      isGlobal: true,
      useFactory: async () => {
        const url = process.env.REDIS_URL;
        if (!url) return { ttl: 5 };
        const store = await redisStore({
          url, // ex: redis://redis_master:6379
          // options ioredis facultatives:
          // family: 4,
          // maxRetriesPerRequest: 3,
        } as any);
        return { store: store as any, ttl: 5 };
      },
    }),

    // Domain modules
    ConfigModule,
    PrismaModule,
    ProvidersModule,
    PetsModule,
    BookingsModule,
    ReviewsModule,
    HealthModule,
    PatientsModule,
    AuthModule,
    UsersModule,
    UploadsModule,
    MapsModule,
    EarningsModule,
    AdoptModule,
    PetshopModule,
    NotificationsModule,
  ],
  providers: [{ provide: APP_INTERCEPTOR, useClass: TransformInterceptor }],
})
export class AppModule {}

import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe, VersioningType } from '@nestjs/common';
import helmet from 'helmet';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { writeFileSync } from 'fs';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // prefix + versioning (/api/v1/...)
  app.setGlobalPrefix('api');
  app.enableVersioning({ type: VersioningType.URI });

  // sécurité avec helmet - autoriser les images cross-origin pour /uploads
  app.use(helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' }, // Allow images to be loaded cross-origin
    crossOriginEmbedderPolicy: false, // Disable COEP to allow cross-origin images
  }));
  app.enableCors({ origin: true, credentials: true });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));

  // Swagger + export OpenAPI
  const config = new DocumentBuilder()
    .setTitle('VetHome API')
    .setDescription('REST API for VetHome')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const doc = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('/docs', app, doc);
  try { writeFileSync('./openapi.json', JSON.stringify(doc, null, 2)); } catch {}

  const port = process.env.PORT || 3000;
  await app.listen(port);
}
bootstrap();

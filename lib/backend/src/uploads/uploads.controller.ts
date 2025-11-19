// src/uploads/uploads.controller.ts
import {
  Body, Controller, Post, Req, UseGuards, UseInterceptors, UploadedFile,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt.guard';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Request } from 'express';
import { diskStorage, type StorageEngine } from 'multer';
import { existsSync, mkdirSync } from 'fs';
import { extname, join } from 'path';
import { randomUUID } from 'crypto';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

@Controller({ path: 'uploads', version: '1' })
@UseGuards(JwtAuthGuard)
export class UploadsController {
  private s3 = new S3Client({
    region: process.env.AWS_REGION || 'rbx',
    endpoint: process.env.S3_ENDPOINT || undefined,
    forcePathStyle: String(process.env.S3_FORCE_PATH_STYLE || 'true').toLowerCase() === 'true',
    credentials: process.env.S3_ACCESS_KEY_ID && process.env.S3_SECRET_ACCESS_KEY ? {
      accessKeyId: process.env.S3_ACCESS_KEY_ID,
      secretAccessKey: process.env.S3_SECRET_ACCESS_KEY,
    } : undefined,
  });

  @Post('local')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: (_req, _file, cb) => {
          const dir = join(process.cwd(), 'public', 'uploads');
          if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
          cb(null, dir);
        },
        filename: (_req, file, cb) => {
          const name = Date.now() + '-' + Math.round(Math.random() * 1e9);
          cb(null, name + extname(file.originalname));
        },
      }) as StorageEngine,
    }),
  )
  async uploadLocal(@UploadedFile() file: Express.Multer.File, @Req() req: Request) {
    const origin = `${req.protocol}://${req.get('host')}`;
    return { url: `${origin}/uploads/${file.filename}` };
  }

  @Post('presign')
  async presign(
    @Req() req: Request & { user: { sub: string } },
    @Body() body: { mimeType: string; folder?: string; ext?: string },
  ) {
    const bucket = process.env.S3_BUCKET!;
    const folder = (body.folder ?? 'uploads').replace(/^\/+|\/+$/g, '');
    const cleanExt = (body.ext ?? '').replace(/^\./, '');
    const key = `${folder}/${req.user.sub}/${randomUUID()}${cleanExt ? '.' + cleanExt : ''}`;

    const putInput: any = {
      Bucket: bucket,
      Key: key,
      ContentType: body.mimeType,
    };

    // Ajoute l’ACL seulement si demandé (et supporté par ton backend S3)
    if (String(process.env.S3_USE_OBJECT_ACL || '').toLowerCase() === 'true') {
      putInput.ACL = 'public-read';
    }

    const put = new PutObjectCommand(putInput);
    const url = await getSignedUrl(this.s3, put, { expiresIn: 900 });

    // URL publique finale (lecture)
    // Pour OVH: utiliser le virtual host style (bucket.endpoint)
    const publicBase = process.env.S3_PUBLIC_ENDPOINT || '';
    let publicUrl: string | undefined;

    if (publicBase) {
      // Virtual host style: https://bucket.s3.rbx.io.cloud.ovh.net/key
      publicUrl = `${publicBase.replace(/\/+$/,'')}/${key}`;
    } else if (process.env.S3_ENDPOINT) {
      // Path style: https://s3.rbx.io.cloud.ovh.net/bucket/key
      publicUrl = `${process.env.S3_ENDPOINT.replace(/\/+$/,'')}/${bucket}/${key}`;
    }

    return { url, key, bucket, publicUrl };
  }
}

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
import { S3Client, PutObjectCommand, PutObjectAclCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

@Controller({ path: 'uploads', version: '1' })
@UseGuards(JwtAuthGuard)
export class UploadsController {
  private s3 = new S3Client({
    region: process.env.AWS_REGION || 'us-east-1',
    endpoint: process.env.S3_ENDPOINT || undefined,
    forcePathStyle: String(process.env.S3_FORCE_PATH_STYLE || '').toLowerCase() === 'true',
    // credentials: pris via AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (env)
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

    // URL publique finale (lecture) — virtual-hosted-style
    const publicBase = process.env.S3_PUBLIC_ENDPOINT || process.env.S3_ENDPOINT || '';
    const publicUrl = publicBase
      ? `${publicBase.replace(/\/+$/,'')}/${key}`
      : undefined;

    // Indiquer si un appel /confirm est nécessaire (OVH ne supporte pas ACL dans presigned URL)
    const needsConfirm = String(process.env.S3_USE_OBJECT_ACL || '').toLowerCase() === 'true';

    return { url, key, bucket, publicUrl, needsConfirm };
  }

  @Post('confirm')
  async confirm(@Body() body: { key: string }) {
    const bucket = process.env.S3_BUCKET!;

    // Définit l'ACL public-read après l'upload (OVH compatibility)
    if (String(process.env.S3_USE_OBJECT_ACL || '').toLowerCase() === 'true') {
      const aclCommand = new PutObjectAclCommand({
        Bucket: bucket,
        Key: body.key,
        ACL: 'public-read',
      });
      await this.s3.send(aclCommand);
    }

    return { success: true };
  }
}

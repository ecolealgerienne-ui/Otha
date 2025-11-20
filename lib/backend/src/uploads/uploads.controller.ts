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

    // Structure: userId/folder/uuid.ext
    // Ex: clxxxx/avatar/uuid.jpg ou clxxxx/pets/uuid.jpg
    const key = `${req.user.sub}/${folder}/${randomUUID()}${cleanExt ? '.' + cleanExt : ''}`;

    console.log('[S3] Generating presigned URL:', {
      bucket,
      key,
      mimeType: body.mimeType,
      region: process.env.AWS_REGION || 'rbx',
      endpoint: process.env.S3_ENDPOINT,
      forcePathStyle: String(process.env.S3_FORCE_PATH_STYLE || 'true').toLowerCase() === 'true',
      hasCredentials: !!(process.env.S3_ACCESS_KEY_ID && process.env.S3_SECRET_ACCESS_KEY),
    });

    // Presigned URL sans ACL (OVH ne supporte pas bien les ACL dans presigned URLs)
    const putInput: any = {
      Bucket: bucket,
      Key: key,
      ContentType: body.mimeType,
    };

    const put = new PutObjectCommand(putInput);
    const url = await getSignedUrl(this.s3, put, { expiresIn: 900 });

    console.log('[S3] Presigned URL generated:', url.substring(0, 150) + '...');

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

    // Headers requis pour l'upload
    const requiredHeaders: Record<string, string> = {
      'Content-Type': body.mimeType,
    };

    // Indiquer au client s'il doit confirmer l'upload pour ACL
    const needsConfirm = String(process.env.S3_USE_OBJECT_ACL || '').toLowerCase() === 'true';

    console.log('[S3] Response to client:', {
      needsConfirm,
      S3_USE_OBJECT_ACL: process.env.S3_USE_OBJECT_ACL,
      key,
      publicUrl,
    });

    return { url, key, bucket, publicUrl, requiredHeaders, needsConfirm };
  }

  @Post('confirm')
  async confirmUpload(
    @Body() body: { key: string },
  ) {
    const bucket = process.env.S3_BUCKET!;
    const key = body.key;

    // Définir l'ACL public-read sur l'objet uploadé (nécessaire pour OVH)
    try {
      console.log(`[S3] Setting ACL public-read for: ${bucket}/${key}`);

      await this.s3.send(new PutObjectAclCommand({
        Bucket: bucket,
        Key: key,
        ACL: 'public-read',
      }));

      console.log(`[S3] ACL set successfully for: ${key}`);
      return { success: true, key };
    } catch (error: any) {
      console.error('[S3] Error setting ACL:', {
        message: error.message,
        code: error.Code || error.code,
        statusCode: error.$metadata?.httpStatusCode,
        key,
      });

      // Retourner l'erreur au client pour qu'il sache que l'ACL a échoué
      return {
        success: false,
        key,
        error: error.message || 'Failed to set public ACL',
        details: {
          code: error.Code || error.code,
          statusCode: error.$metadata?.httpStatusCode,
        }
      };
    }
  }
}

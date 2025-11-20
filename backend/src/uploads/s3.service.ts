// src/uploads/s3.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { S3Client, DeleteObjectCommand, ListObjectsV2Command } from '@aws-sdk/client-s3';

@Injectable()
export class S3Service {
  private readonly logger = new Logger(S3Service.name);
  private s3: S3Client;
  private bucket: string;

  constructor() {
    this.bucket = process.env.S3_BUCKET || 'vethome';
    this.s3 = new S3Client({
      region: process.env.AWS_REGION || 'rbx',
      endpoint: process.env.S3_ENDPOINT || undefined,
      forcePathStyle: String(process.env.S3_FORCE_PATH_STYLE || 'true').toLowerCase() === 'true',
      credentials: process.env.S3_ACCESS_KEY_ID && process.env.S3_SECRET_ACCESS_KEY ? {
        accessKeyId: process.env.S3_ACCESS_KEY_ID,
        secretAccessKey: process.env.S3_SECRET_ACCESS_KEY,
      } : undefined,
    });
  }

  /**
   * Extrait la clé S3 depuis une URL publique
   * Ex: https://vethome.s3.rbx.io.cloud.ovh.net/avatars/userId/file.jpg -> avatars/userId/file.jpg
   */
  extractKeyFromUrl(url: string): string | null {
    if (!url) return null;

    try {
      const urlObj = new URL(url);
      // Virtual host style: bucket.endpoint/key
      // Path style: endpoint/bucket/key
      let path = urlObj.pathname;

      // Remove leading slash
      if (path.startsWith('/')) {
        path = path.substring(1);
      }

      // If path starts with bucket name (path style), remove it
      if (path.startsWith(`${this.bucket}/`)) {
        path = path.substring(this.bucket.length + 1);
      }

      return path || null;
    } catch {
      return null;
    }
  }

  /**
   * Supprime un objet du bucket S3
   */
  async deleteObject(key: string): Promise<boolean> {
    if (!key) return false;

    try {
      await this.s3.send(new DeleteObjectCommand({
        Bucket: this.bucket,
        Key: key,
      }));
      this.logger.log(`Deleted S3 object: ${key}`);
      return true;
    } catch (error) {
      this.logger.error(`Failed to delete S3 object ${key}:`, error);
      return false;
    }
  }

  /**
   * Supprime un objet à partir de son URL publique
   */
  async deleteByUrl(url: string): Promise<boolean> {
    const key = this.extractKeyFromUrl(url);
    if (!key) {
      this.logger.warn(`Could not extract key from URL: ${url}`);
      return false;
    }
    return this.deleteObject(key);
  }

  /**
   * Supprime tous les objets dans un préfixe (dossier)
   * Ex: deleteByPrefix('avatars/userId123/') supprime toutes les images de cet utilisateur
   */
  async deleteByPrefix(prefix: string): Promise<number> {
    if (!prefix) return 0;

    try {
      // Liste tous les objets avec ce préfixe
      const listCommand = new ListObjectsV2Command({
        Bucket: this.bucket,
        Prefix: prefix,
      });

      const response = await this.s3.send(listCommand);
      const objects = response.Contents || [];

      if (objects.length === 0) {
        return 0;
      }

      // Supprime chaque objet
      let deleted = 0;
      for (const obj of objects) {
        if (obj.Key) {
          const success = await this.deleteObject(obj.Key);
          if (success) deleted++;
        }
      }

      this.logger.log(`Deleted ${deleted} objects with prefix: ${prefix}`);
      return deleted;
    } catch (error) {
      this.logger.error(`Failed to delete objects with prefix ${prefix}:`, error);
      return 0;
    }
  }

  /**
   * Vérifie si une URL est une URL S3 de notre bucket
   */
  isS3Url(url: string): boolean {
    if (!url) return false;

    const s3Patterns = [
      process.env.S3_PUBLIC_ENDPOINT,
      process.env.S3_ENDPOINT,
      's3.rbx.io.cloud.ovh.net',
    ].filter(Boolean);

    return s3Patterns.some(pattern => url.includes(pattern!));
  }
}

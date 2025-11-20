import { Module } from '@nestjs/common';
import { MulterModule } from '@nestjs/platform-express';
import { UploadsController } from './uploads.controller';
import { S3Service } from './s3.service';

@Module({
  imports: [
    MulterModule.register({
      dest: './public/uploads',
    }),
  ],
  controllers: [UploadsController],
  providers: [S3Service],
  exports: [S3Service],
})
export class UploadsModule {}

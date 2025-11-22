// src/pets/dto.ts
import { ApiPropertyOptional, ApiProperty } from '@nestjs/swagger';
import { IsEnum, IsNumber, IsOptional, IsString, IsUrl, IsISO8601 } from 'class-validator';
import { Type } from 'class-transformer';

export class CreatePetDto {
  @ApiProperty() @IsString()
  name!: string;

  @ApiProperty({ enum: ['MALE','FEMALE','UNKNOWN'] })
  @IsEnum(['MALE','FEMALE','UNKNOWN'])
  gender!: 'MALE'|'FEMALE'|'UNKNOWN';

  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsNumber()
  weightKg?: number;

  @ApiPropertyOptional() @IsOptional() @IsString()
  color?: string;

  // <- tu utilises "country" pour la ville dans l’app
  @ApiPropertyOptional() @IsOptional() @IsString()
  country?: string;

  // <- type d’animal
  @ApiPropertyOptional() @IsOptional() @IsString()
  idNumber?: string;

  @ApiPropertyOptional() @IsOptional() @IsString()
  breed?: string;

  @ApiPropertyOptional() @IsOptional() @IsISO8601()
  neuteredAt?: string; // string ISO en entrée

  @ApiPropertyOptional() @IsOptional() @IsISO8601()
  birthDate?: string; // Date de naissance ISO

  @ApiPropertyOptional() @IsOptional() @IsString()
  microchipNumber?: string; // Numéro de puce électronique

  @ApiPropertyOptional() @IsOptional() @IsString()
  allergiesNotes?: string; // Notes sur les allergies

  @ApiPropertyOptional() @IsOptional() @IsString()
  description?: string; // Description/notes générales

  @ApiPropertyOptional() @IsOptional() @IsUrl()
  photoUrl?: string;
}

export class UpdatePetDto extends CreatePetDto {}

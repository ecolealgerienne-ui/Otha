import { IsString, IsOptional, IsEnum, MaxLength, MinLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum CareerTypeDto {
  REQUEST = 'REQUEST',
  OFFER = 'OFFER',
}

export class CreateCareerPostDto {
  @ApiProperty({ enum: CareerTypeDto, description: 'Type de post: REQUEST (demande) ou OFFER (offre)' })
  @IsEnum(CareerTypeDto)
  type!: CareerTypeDto;

  @ApiProperty({ description: 'Titre de l\'annonce' })
  @IsString()
  @MinLength(5)
  @MaxLength(100)
  title!: string;

  @ApiProperty({ description: 'Bio publique (visible par tous)' })
  @IsString()
  @MinLength(20)
  @MaxLength(500)
  publicBio!: string;

  @ApiPropertyOptional({ description: 'Ville' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;

  @ApiPropertyOptional({ description: 'Domaine (ex: Vétérinaire, ASV, etc.)' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  domain?: string;

  @ApiPropertyOptional({ description: 'Durée (ex: 3 mois, CDI, CDD)' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  duration?: string;

  // Champs privés (pour REQUEST - visibles par pros uniquement)
  @ApiPropertyOptional({ description: 'Nom complet (privé, visible par pros)' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  fullName?: string;

  @ApiPropertyOptional({ description: 'Email de contact (privé, visible par pros)' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  email?: string;

  @ApiPropertyOptional({ description: 'Téléphone (privé, visible par pros)' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  phone?: string;

  @ApiPropertyOptional({ description: 'Bio détaillée (privée, visible par pros)' })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  detailedBio?: string;

  @ApiPropertyOptional({ description: 'URL de l\'image du CV (PNG)' })
  @IsOptional()
  @IsString()
  cvImageUrl?: string;

  // Champs pour OFFER
  @ApiPropertyOptional({ description: 'Salaire/rémunération (pour OFFER)' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  salary?: string;

  @ApiPropertyOptional({ description: 'Prérequis (pour OFFER)' })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  requirements?: string;
}

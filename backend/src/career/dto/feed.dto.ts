import { IsOptional, IsString, IsEnum } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { CareerTypeDto } from './create-career-post.dto';

export class CareerFeedQueryDto {
  @ApiPropertyOptional({ enum: CareerTypeDto, description: 'Filtrer par type' })
  @IsOptional()
  @IsEnum(CareerTypeDto)
  type?: CareerTypeDto;

  @ApiPropertyOptional({ description: 'Filtrer par ville' })
  @IsOptional()
  @IsString()
  city?: string;

  @ApiPropertyOptional({ description: 'Filtrer par domaine' })
  @IsOptional()
  @IsString()
  domain?: string;

  @ApiPropertyOptional({ description: 'Curseur pour pagination' })
  @IsOptional()
  @IsString()
  cursor?: string;

  @ApiPropertyOptional({ description: 'Limite de résultats' })
  @IsOptional()
  limit?: number;
}

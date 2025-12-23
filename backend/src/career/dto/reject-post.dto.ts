import { IsOptional, IsString, MaxLength, IsArray } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class RejectCareerPostDto {
  @ApiPropertyOptional({ description: 'Raisons du rejet' })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  reasons?: string[];

  @ApiPropertyOptional({ description: 'Note additionnelle' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

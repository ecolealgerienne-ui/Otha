import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsArray, IsOptional, IsString, MaxLength } from 'class-validator';

export class RejectPostDto {
  @ApiPropertyOptional({ type: [String], description: 'Raisons du refus' })
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

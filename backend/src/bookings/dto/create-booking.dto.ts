import { IsString, IsOptional, IsNumber, IsNotEmpty, IsArray, ArrayNotEmpty } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateBookingDto {
  @IsString() @IsNotEmpty()
  serviceId!: string;

  @IsOptional() @IsString()
  scheduledAt?: string;

  @IsOptional() @IsNumber()
  scheduledAtTs?: number;

  // Champs pour garderies
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  petIds?: string[];

  @IsOptional() @IsString()
  clientNotes?: string;

  @IsOptional() @IsString()
  endDate?: string;

  @IsOptional() @IsNumber()
  @Type(() => Number)
  commissionDa?: number;
}

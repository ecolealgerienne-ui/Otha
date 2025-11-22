import { IsString, IsOptional, IsNumber, IsNotEmpty, IsArray } from 'class-validator';

export class CreateBookingDto {
  @IsString() @IsNotEmpty()
  serviceId!: string;

  @IsOptional() @IsString()
  scheduledAt?: string;

  @IsOptional() @IsNumber()
  scheduledAtTs?: number;

  // Champs pour garderies
  @IsOptional() @IsArray()
  petIds?: string[];

  @IsOptional() @IsString()
  clientNotes?: string;

  @IsOptional() @IsString()
  endDate?: string;

  @IsOptional() @IsNumber()
  commissionDa?: number;
}

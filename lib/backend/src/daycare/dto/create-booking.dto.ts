import { IsString, IsInt, IsDateString, IsOptional, Min } from 'class-validator';

export class CreateDaycareBookingDto {
  @IsString()
  petId: string;

  @IsString()
  providerId: string;

  @IsDateString()
  startDate: string; // ISO 8601 format

  @IsDateString()
  endDate: string; // ISO 8601 format

  @IsInt()
  @Min(0)
  priceDa: number; // Prix de base en DA

  @IsOptional()
  @IsString()
  notes?: string; // Notes optionnelles du client
}

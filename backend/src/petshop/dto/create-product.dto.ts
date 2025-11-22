import { IsString, IsInt, IsOptional, IsPositive, IsBoolean, IsArray } from 'class-validator';

export class CreateProductDto {
  @IsString()
  title!: string;

  @IsString()
  description!: string;

  @IsInt()
  @IsPositive()
  priceDa!: number;

  @IsOptional()
  @IsInt()
  @IsPositive()
  stock?: number;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  imageUrls?: string[];

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}




import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsArray, IsEnum, IsInt, IsNumber, IsOptional, IsString, IsUrl, MaxLength, Min, ValidateNested, ArrayMaxSize } from 'class-validator';
import { Type } from 'class-transformer';

export class AdoptImageInput {
  @ApiProperty() @IsUrl()
  url!: string;

  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0)
  width?: number;

  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0)
  height?: number;

  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0)
  order?: number;
}

export class CreateAdoptPostDto {
  @ApiProperty() @IsString() @MaxLength(140)
  title!: string;

  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(100)
  animalName?: string;

  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(2000)
  description?: string;

  @ApiProperty() @IsString() @MaxLength(32)
  species!: string; // "dog" | "cat" | ...

  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(16)
  sex?: string;     // "male" | "female" | "unknown"

  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0)
  ageMonths?: number;

  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(8)
  size?: string;    // "S" | "M" | "L" | ...

  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(32)
  color?: string;

  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(64)
  city?: string;

  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(140)
  address?: string;

  @ApiPropertyOptional() @IsOptional() @IsUrl()
  mapsUrl?: string;

  @ApiPropertyOptional() @IsOptional() @IsNumber()
  lat?: number;

  @ApiPropertyOptional() @IsOptional() @IsNumber()
  lng?: number;

  @ApiProperty({ type: [AdoptImageInput], maxItems: 3 })
  @IsArray() @ArrayMaxSize(3) @ValidateNested({ each: true }) @Type(() => AdoptImageInput)
  images!: AdoptImageInput[];
}

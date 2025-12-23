import { IsString, MaxLength, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SendCareerMessageDto {
  @ApiProperty({ description: 'Contenu du message' })
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  content: string;
}

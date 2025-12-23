import { PartialType, OmitType } from '@nestjs/swagger';
import { CreateCareerPostDto } from './create-career-post.dto';

export class UpdateCareerPostDto extends PartialType(
  OmitType(CreateCareerPostDto, ['type'] as const),
) {}

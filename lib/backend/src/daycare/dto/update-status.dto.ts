import { IsEnum } from 'class-validator';

export enum DaycareBookingStatus {
  PENDING = 'PENDING',
  CONFIRMED = 'CONFIRMED',
  IN_PROGRESS = 'IN_PROGRESS',
  COMPLETED = 'COMPLETED',
  CANCELLED = 'CANCELLED',
}

export class UpdateBookingStatusDto {
  @IsEnum(DaycareBookingStatus)
  status: DaycareBookingStatus;
}

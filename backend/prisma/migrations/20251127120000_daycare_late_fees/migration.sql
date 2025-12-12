-- AlterTable: Add late fee fields and client proximity notification
ALTER TABLE "DaycareBooking" ADD COLUMN "lateFeeDa" INTEGER;
ALTER TABLE "DaycareBooking" ADD COLUMN "lateFeeHours" DOUBLE PRECISION;
ALTER TABLE "DaycareBooking" ADD COLUMN "lateFeeStatus" TEXT;
ALTER TABLE "DaycareBooking" ADD COLUMN "lateFeeAcceptedAt" TIMESTAMP(3);
ALTER TABLE "DaycareBooking" ADD COLUMN "lateFeeNote" TEXT;
ALTER TABLE "DaycareBooking" ADD COLUMN "clientNearbyAt" TIMESTAMP(3);

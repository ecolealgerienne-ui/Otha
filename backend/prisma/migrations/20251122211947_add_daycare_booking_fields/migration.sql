-- AlterTable
ALTER TABLE "Booking" ADD COLUMN     "clientNotes" TEXT,
ADD COLUMN     "commissionDa" INTEGER,
ADD COLUMN     "endDate" TIMESTAMP(3),
ADD COLUMN     "petIds" TEXT[] DEFAULT ARRAY[]::TEXT[];

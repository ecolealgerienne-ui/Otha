-- AlterTable
ALTER TABLE "MedicalRecord" ADD COLUMN "bookingId" TEXT,
ADD COLUMN "daycareBookingId" TEXT,
ADD COLUMN "providerType" TEXT,
ADD COLUMN "durationMinutes" INTEGER;

-- CreateIndex
CREATE INDEX "MedicalRecord_bookingId_idx" ON "MedicalRecord"("bookingId");

-- CreateIndex
CREATE INDEX "MedicalRecord_daycareBookingId_idx" ON "MedicalRecord"("daycareBookingId");

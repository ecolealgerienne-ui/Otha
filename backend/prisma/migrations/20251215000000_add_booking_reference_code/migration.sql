-- AlterTable
ALTER TABLE "Booking" ADD COLUMN "referenceCode" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "Booking_referenceCode_key" ON "Booking"("referenceCode");

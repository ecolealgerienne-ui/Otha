-- CreateEnum
CREATE TYPE "DaycareBookingStatus" AS ENUM ('PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED');

-- CreateTable
CREATE TABLE "DaycareBooking" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "petId" TEXT NOT NULL,
    "status" "DaycareBookingStatus" NOT NULL DEFAULT 'PENDING',
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,
    "actualDropOff" TIMESTAMP(3),
    "actualPickup" TIMESTAMP(3),
    "priceDa" INTEGER NOT NULL,
    "commissionDa" INTEGER NOT NULL DEFAULT 100,
    "totalDa" INTEGER NOT NULL,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DaycareBooking_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "DaycareBooking_userId_idx" ON "DaycareBooking"("userId");

-- CreateIndex
CREATE INDEX "DaycareBooking_providerId_idx" ON "DaycareBooking"("providerId");

-- CreateIndex
CREATE INDEX "DaycareBooking_petId_idx" ON "DaycareBooking"("petId");

-- CreateIndex
CREATE INDEX "DaycareBooking_providerId_startDate_idx" ON "DaycareBooking"("providerId", "startDate");

-- CreateIndex
CREATE INDEX "DaycareBooking_status_idx" ON "DaycareBooking"("status");

-- AddForeignKey
ALTER TABLE "DaycareBooking" ADD CONSTRAINT "DaycareBooking_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DaycareBooking" ADD CONSTRAINT "DaycareBooking_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "ProviderProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DaycareBooking" ADD CONSTRAINT "DaycareBooking_petId_fkey" FOREIGN KEY ("petId") REFERENCES "Pet"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

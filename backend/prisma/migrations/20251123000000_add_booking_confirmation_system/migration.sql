-- AlterEnum
ALTER TYPE "BookingStatus" ADD VALUE 'AWAITING_CONFIRMATION';
ALTER TYPE "BookingStatus" ADD VALUE 'PENDING_PRO_VALIDATION';
ALTER TYPE "BookingStatus" ADD VALUE 'DISPUTED';
ALTER TYPE "BookingStatus" ADD VALUE 'EXPIRED';

-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'BOOKING_NEEDS_VALIDATION';

-- AlterTable
ALTER TABLE "Booking" ADD COLUMN "gracePeriodEndsAt" TIMESTAMP(3),
ADD COLUMN "clientConfirmedAt" TIMESTAMP(3),
ADD COLUMN "proConfirmedAt" TIMESTAMP(3),
ADD COLUMN "proResponseDeadline" TIMESTAMP(3),
ADD COLUMN "cancellationReason" TEXT,
ADD COLUMN "disputeNote" TEXT;

-- AlterTable
ALTER TABLE "Review" ADD COLUMN "isPending" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "AdminFlag" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "bookingId" TEXT,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "AdminFlag_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Booking_status_gracePeriodEndsAt_idx" ON "Booking"("status", "gracePeriodEndsAt");

-- CreateIndex
CREATE INDEX "AdminFlag_userId_resolved_idx" ON "AdminFlag"("userId", "resolved");

-- CreateIndex
CREATE INDEX "AdminFlag_createdAt_idx" ON "AdminFlag"("createdAt");

-- AddForeignKey
ALTER TABLE "AdminFlag" ADD CONSTRAINT "AdminFlag_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateEnum
CREATE TYPE "TrustStatus" AS ENUM ('NEW', 'VERIFIED', 'RESTRICTED');

-- AlterTable
ALTER TABLE "User" ADD COLUMN "trustStatus" "TrustStatus" NOT NULL DEFAULT 'NEW',
ADD COLUMN "restrictedUntil" TIMESTAMP(3),
ADD COLUMN "noShowCount" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "verifiedAt" TIMESTAMP(3),
ADD COLUMN "lastModifiedBooking" TEXT;

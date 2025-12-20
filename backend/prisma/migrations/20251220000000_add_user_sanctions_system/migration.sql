-- CreateEnum
CREATE TYPE "SanctionType" AS ENUM ('WARNING', 'SUSPENSION', 'BAN', 'UNBAN', 'LIFT');

-- AlterTable: Add sanction fields to User
ALTER TABLE "User" ADD COLUMN "isBanned" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "User" ADD COLUMN "bannedAt" TIMESTAMP(3);
ALTER TABLE "User" ADD COLUMN "bannedReason" TEXT;
ALTER TABLE "User" ADD COLUMN "bannedBy" TEXT;
ALTER TABLE "User" ADD COLUMN "suspendedUntil" TIMESTAMP(3);

-- CreateTable: UserSanction
CREATE TABLE "UserSanction" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "type" "SanctionType" NOT NULL,
    "reason" TEXT NOT NULL,
    "duration" INTEGER,
    "expiresAt" TIMESTAMP(3),
    "issuedBy" TEXT NOT NULL,
    "issuedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "liftedAt" TIMESTAMP(3),
    "liftedBy" TEXT,
    "metadata" JSONB,

    CONSTRAINT "UserSanction_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "User_isBanned_idx" ON "User"("isBanned");

-- CreateIndex
CREATE INDEX "UserSanction_userId_idx" ON "UserSanction"("userId");

-- CreateIndex
CREATE INDEX "UserSanction_userId_type_idx" ON "UserSanction"("userId", "type");

-- CreateIndex
CREATE INDEX "UserSanction_issuedAt_idx" ON "UserSanction"("issuedAt");

-- CreateIndex
CREATE INDEX "UserSanction_issuedBy_idx" ON "UserSanction"("issuedBy");

-- AddForeignKey
ALTER TABLE "UserSanction" ADD CONSTRAINT "UserSanction_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

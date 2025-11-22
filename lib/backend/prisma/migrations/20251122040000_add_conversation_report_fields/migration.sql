-- AlterTable
ALTER TABLE "AdoptConversation" ADD COLUMN "reportedByOwner" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "reportReasonByOwner" TEXT,
ADD COLUMN "reportedAtByOwner" TIMESTAMP(3),
ADD COLUMN "reportedByAdopter" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "reportReasonByAdopter" TEXT,
ADD COLUMN "reportedAtByAdopter" TIMESTAMP(3);

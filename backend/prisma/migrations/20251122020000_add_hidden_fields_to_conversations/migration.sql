-- AlterTable
ALTER TABLE "AdoptConversation" ADD COLUMN "hiddenByOwner" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "hiddenByAdopter" BOOLEAN NOT NULL DEFAULT false;

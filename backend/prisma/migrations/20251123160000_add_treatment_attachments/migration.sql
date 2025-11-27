-- AlterTable
ALTER TABLE "Treatment" ADD COLUMN "attachments" TEXT[] DEFAULT ARRAY[]::TEXT[];

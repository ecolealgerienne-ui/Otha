-- AlterTable: Add custom commission fields to ProviderProfile
ALTER TABLE "ProviderProfile" ADD COLUMN IF NOT EXISTS "vetCommissionDa" INTEGER NOT NULL DEFAULT 100;
ALTER TABLE "ProviderProfile" ADD COLUMN IF NOT EXISTS "daycareHourlyCommissionDa" INTEGER NOT NULL DEFAULT 10;
ALTER TABLE "ProviderProfile" ADD COLUMN IF NOT EXISTS "daycareDailyCommissionDa" INTEGER NOT NULL DEFAULT 100;

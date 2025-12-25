-- AddColumn: petshopCommissionPercent to ProviderProfile
ALTER TABLE "ProviderProfile" ADD COLUMN "petshopCommissionPercent" INTEGER NOT NULL DEFAULT 5;

-- AddColumn: subtotalDa and commissionDa to Order
ALTER TABLE "Order" ADD COLUMN "subtotalDa" INTEGER;
ALTER TABLE "Order" ADD COLUMN "commissionDa" INTEGER;

-- Update existing orders: set subtotalDa = totalDa and commissionDa = 0
UPDATE "Order" SET "subtotalDa" = "totalDa", "commissionDa" = 0 WHERE "subtotalDa" IS NULL;

-- Make subtotalDa and commissionDa NOT NULL after migration
ALTER TABLE "Order" ALTER COLUMN "subtotalDa" SET NOT NULL;
ALTER TABLE "Order" ALTER COLUMN "commissionDa" SET NOT NULL;

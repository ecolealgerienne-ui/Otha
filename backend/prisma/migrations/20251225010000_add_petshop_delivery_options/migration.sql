-- AddColumns: delivery options to ProviderProfile
ALTER TABLE "ProviderProfile" ADD COLUMN "deliveryEnabled" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "ProviderProfile" ADD COLUMN "pickupEnabled" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "ProviderProfile" ADD COLUMN "deliveryFeeDa" INTEGER;
ALTER TABLE "ProviderProfile" ADD COLUMN "freeDeliveryAboveDa" INTEGER;

-- AddColumns: delivery info to Order
ALTER TABLE "Order" ADD COLUMN "deliveryFeeDa" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Order" ADD COLUMN "deliveryMode" TEXT NOT NULL DEFAULT 'pickup';

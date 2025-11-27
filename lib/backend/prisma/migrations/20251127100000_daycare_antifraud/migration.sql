-- Migration: daycare_antifraud
-- Ajoute le système anti-fraude pour les réservations garderie

-- Ajouter les nouveaux statuts à l'enum
ALTER TYPE "DaycareBookingStatus" ADD VALUE IF NOT EXISTS 'PENDING_DROP_VALIDATION';
ALTER TYPE "DaycareBookingStatus" ADD VALUE IF NOT EXISTS 'PENDING_PICKUP_VALIDATION';
ALTER TYPE "DaycareBookingStatus" ADD VALUE IF NOT EXISTS 'DISPUTED';

-- Ajouter les champs anti-fraude pour le dépôt
ALTER TABLE "DaycareBooking" ADD COLUMN IF NOT EXISTS "clientDropConfirmedAt" TIMESTAMP(3);
ALTER TABLE "DaycareBooking" ADD COLUMN IF NOT EXISTS "dropConfirmationMethod" TEXT;
ALTER TABLE "DaycareBooking" ADD COLUMN IF NOT EXISTS "dropCheckinLat" DOUBLE PRECISION;
ALTER TABLE "DaycareBooking" ADD COLUMN IF NOT EXISTS "dropCheckinLng" DOUBLE PRECISION;
ALTER TABLE "DaycareBooking" ADD COLUMN IF NOT EXISTS "dropOtpCode" TEXT;
ALTER TABLE "DaycareBooking" ADD COLUMN IF NOT EXISTS "dropOtpExpiresAt" TIMESTAMP(3);

-- Ajouter les champs anti-fraude pour le retrait
ALTER TABLE "DaycareBooking" ADD COLUMN IF NOT EXISTS "clientPickupConfirmedAt" TIMESTAMP(3);
ALTER TABLE "DaycareBooking" ADD COLUMN IF NOT EXISTS "pickupConfirmationMethod" TEXT;
ALTER TABLE "DaycareBooking" ADD COLUMN IF NOT EXISTS "pickupCheckinLat" DOUBLE PRECISION;
ALTER TABLE "DaycareBooking" ADD COLUMN IF NOT EXISTS "pickupCheckinLng" DOUBLE PRECISION;
ALTER TABLE "DaycareBooking" ADD COLUMN IF NOT EXISTS "pickupOtpCode" TEXT;
ALTER TABLE "DaycareBooking" ADD COLUMN IF NOT EXISTS "pickupOtpExpiresAt" TIMESTAMP(3);

-- Ajouter le champ note de litige
ALTER TABLE "DaycareBooking" ADD COLUMN IF NOT EXISTS "disputeNote" TEXT;

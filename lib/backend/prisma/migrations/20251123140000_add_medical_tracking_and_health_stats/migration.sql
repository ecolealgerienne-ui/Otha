-- AlterTable MedicalRecord: Ajout des champs pour l'historique automatique des RDV
ALTER TABLE "MedicalRecord" ADD COLUMN IF NOT EXISTS "bookingId" TEXT,
ADD COLUMN IF NOT EXISTS "daycareBookingId" TEXT,
ADD COLUMN IF NOT EXISTS "providerType" TEXT,
ADD COLUMN IF NOT EXISTS "durationMinutes" INTEGER;

-- AlterTable MedicalRecord: Ajout des champs pour les statistiques de santé
ALTER TABLE "MedicalRecord" ADD COLUMN IF NOT EXISTS "weightKg" DECIMAL(5,2),
ADD COLUMN IF NOT EXISTS "temperatureC" DECIMAL(4,2),
ADD COLUMN IF NOT EXISTS "heartRate" INTEGER;

-- CreateIndex: Index pour les bookings
CREATE INDEX IF NOT EXISTS "MedicalRecord_bookingId_idx" ON "MedicalRecord"("bookingId");
CREATE INDEX IF NOT EXISTS "MedicalRecord_daycareBookingId_idx" ON "MedicalRecord"("daycareBookingId");

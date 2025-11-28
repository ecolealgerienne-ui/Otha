-- AlterTable: Add providerId to MedicalRecord
ALTER TABLE "MedicalRecord" ADD COLUMN "providerId" TEXT;

-- AlterTable: Add providerId to DiseaseTracking
ALTER TABLE "DiseaseTracking" ADD COLUMN "providerId" TEXT;

-- CreateTable: Prescription (Ordonnances)
CREATE TABLE "Prescription" (
    "id" TEXT NOT NULL,
    "petId" TEXT NOT NULL,
    "providerId" TEXT,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "imageUrl" TEXT,
    "date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Prescription_pkey" PRIMARY KEY ("id")
);

-- CreateTable: HealthStat (Statistiques de santé)
CREATE TABLE "HealthStat" (
    "id" TEXT NOT NULL,
    "petId" TEXT NOT NULL,
    "providerId" TEXT,
    "type" TEXT NOT NULL,
    "value" DOUBLE PRECISION NOT NULL,
    "unit" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "HealthStat_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Prescription_petId_date_idx" ON "Prescription"("petId", "date");
CREATE INDEX "Prescription_providerId_idx" ON "Prescription"("providerId");

-- CreateIndex
CREATE INDEX "HealthStat_petId_type_date_idx" ON "HealthStat"("petId", "type", "date");
CREATE INDEX "HealthStat_providerId_idx" ON "HealthStat"("providerId");

-- CreateIndex
CREATE INDEX "MedicalRecord_providerId_idx" ON "MedicalRecord"("providerId");
CREATE INDEX "DiseaseTracking_providerId_idx" ON "DiseaseTracking"("providerId");

-- AddForeignKey
ALTER TABLE "MedicalRecord" ADD CONSTRAINT "MedicalRecord_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "ProviderProfile"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DiseaseTracking" ADD CONSTRAINT "DiseaseTracking_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "ProviderProfile"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Prescription" ADD CONSTRAINT "Prescription_petId_fkey" FOREIGN KEY ("petId") REFERENCES "Pet"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Prescription" ADD CONSTRAINT "Prescription_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "ProviderProfile"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "HealthStat" ADD CONSTRAINT "HealthStat_petId_fkey" FOREIGN KEY ("petId") REFERENCES "Pet"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "HealthStat" ADD CONSTRAINT "HealthStat_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "ProviderProfile"("id") ON DELETE SET NULL ON UPDATE CASCADE;

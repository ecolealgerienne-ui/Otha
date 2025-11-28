-- AlterTable
ALTER TABLE "MedicalRecord" ADD COLUMN "providerId" TEXT;

-- CreateIndex
CREATE INDEX "MedicalRecord_providerId_idx" ON "MedicalRecord"("providerId");

-- AddForeignKey
ALTER TABLE "MedicalRecord" ADD CONSTRAINT "MedicalRecord_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "ProviderProfile"("id") ON DELETE SET NULL ON UPDATE CASCADE;

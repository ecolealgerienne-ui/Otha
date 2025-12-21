-- Add providerId column to DiseaseTracking
ALTER TABLE "DiseaseTracking" ADD COLUMN "providerId" TEXT;

-- Create index for provider lookups
CREATE INDEX "DiseaseTracking_providerId_idx" ON "DiseaseTracking"("providerId");

-- Add foreign key constraint (optional - provider may not exist for owner-created entries)
ALTER TABLE "DiseaseTracking" ADD CONSTRAINT "DiseaseTracking_providerId_fkey"
    FOREIGN KEY ("providerId") REFERENCES "ProviderProfile"("id") ON DELETE SET NULL ON UPDATE CASCADE;

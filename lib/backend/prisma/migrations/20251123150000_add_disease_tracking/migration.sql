-- CreateTable: DiseaseTracking
CREATE TABLE "DiseaseTracking" (
    "id" TEXT NOT NULL,
    "petId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "status" TEXT NOT NULL,
    "severity" TEXT,
    "diagnosisDate" TIMESTAMP(3) NOT NULL,
    "curedDate" TIMESTAMP(3),
    "vetId" TEXT,
    "vetName" TEXT,
    "symptoms" TEXT,
    "treatment" TEXT,
    "images" TEXT[],
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DiseaseTracking_pkey" PRIMARY KEY ("id")
);

-- CreateTable: DiseaseProgressEntry
CREATE TABLE "DiseaseProgressEntry" (
    "id" TEXT NOT NULL,
    "diseaseId" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "notes" TEXT NOT NULL,
    "images" TEXT[],
    "severity" TEXT,
    "treatmentUpdate" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DiseaseProgressEntry_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "DiseaseTracking_petId_status_idx" ON "DiseaseTracking"("petId", "status");

-- CreateIndex
CREATE INDEX "DiseaseTracking_petId_diagnosisDate_idx" ON "DiseaseTracking"("petId", "diagnosisDate");

-- CreateIndex
CREATE INDEX "DiseaseProgressEntry_diseaseId_date_idx" ON "DiseaseProgressEntry"("diseaseId", "date");

-- AddForeignKey
ALTER TABLE "DiseaseTracking" ADD CONSTRAINT "DiseaseTracking_petId_fkey" FOREIGN KEY ("petId") REFERENCES "Pet"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DiseaseProgressEntry" ADD CONSTRAINT "DiseaseProgressEntry_diseaseId_fkey" FOREIGN KEY ("diseaseId") REFERENCES "DiseaseTracking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

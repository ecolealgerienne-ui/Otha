-- AlterTable
ALTER TABLE "AdoptConversation"
ADD COLUMN "pendingAdoptionConfirmation" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "pendingAdoptionRequestedAt" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "AdoptConversation_adopterId_pendingAdoptionConfirmation_idx" ON "AdoptConversation"("adopterId", "pendingAdoptionConfirmation");

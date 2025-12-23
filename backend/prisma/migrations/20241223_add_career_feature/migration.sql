-- CreateEnum
CREATE TYPE "CareerStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "CareerType" AS ENUM ('REQUEST', 'OFFER');

-- CreateTable
CREATE TABLE "CareerPost" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "status" "CareerStatus" NOT NULL DEFAULT 'PENDING',
    "type" "CareerType" NOT NULL,
    "title" TEXT NOT NULL,
    "publicBio" TEXT NOT NULL,
    "city" TEXT,
    "domain" TEXT,
    "duration" TEXT,
    "fullName" TEXT,
    "email" TEXT,
    "phone" TEXT,
    "detailedBio" TEXT,
    "cvImageUrl" TEXT,
    "salary" TEXT,
    "requirements" TEXT,
    "createdById" TEXT NOT NULL,
    "moderationNote" TEXT,
    "approvedAt" TIMESTAMP(3),
    "rejectedAt" TIMESTAMP(3),
    "archivedAt" TIMESTAMP(3),

    CONSTRAINT "CareerPost_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CareerConversation" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "postId" TEXT NOT NULL,
    "participantId" TEXT NOT NULL,
    "participantAnonymousName" TEXT,
    "hiddenByOwner" BOOLEAN NOT NULL DEFAULT false,
    "hiddenByParticipant" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "CareerConversation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CareerMessage" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "conversationId" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "readAt" TIMESTAMP(3),

    CONSTRAINT "CareerMessage_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "CareerPost_status_type_createdAt_idx" ON "CareerPost"("status", "type", "createdAt");

-- CreateIndex
CREATE INDEX "CareerPost_city_idx" ON "CareerPost"("city");

-- CreateIndex
CREATE INDEX "CareerPost_type_status_idx" ON "CareerPost"("type", "status");

-- CreateIndex
CREATE UNIQUE INDEX "CareerPost_createdById_type_key" ON "CareerPost"("createdById", "type");

-- CreateIndex
CREATE INDEX "CareerConversation_postId_idx" ON "CareerConversation"("postId");

-- CreateIndex
CREATE INDEX "CareerConversation_participantId_idx" ON "CareerConversation"("participantId");

-- CreateIndex
CREATE UNIQUE INDEX "CareerConversation_postId_participantId_key" ON "CareerConversation"("postId", "participantId");

-- CreateIndex
CREATE INDEX "CareerMessage_conversationId_createdAt_idx" ON "CareerMessage"("conversationId", "createdAt");

-- CreateIndex
CREATE INDEX "CareerMessage_senderId_idx" ON "CareerMessage"("senderId");

-- AddForeignKey
ALTER TABLE "CareerPost" ADD CONSTRAINT "CareerPost_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CareerConversation" ADD CONSTRAINT "CareerConversation_postId_fkey" FOREIGN KEY ("postId") REFERENCES "CareerPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CareerConversation" ADD CONSTRAINT "CareerConversation_participantId_fkey" FOREIGN KEY ("participantId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CareerMessage" ADD CONSTRAINT "CareerMessage_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "CareerConversation"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CareerMessage" ADD CONSTRAINT "CareerMessage_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

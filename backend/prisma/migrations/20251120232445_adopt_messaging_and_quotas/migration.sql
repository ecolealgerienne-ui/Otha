-- CreateEnum
CREATE TYPE "AdoptRequestStatus" AS ENUM ('PENDING', 'ACCEPTED', 'REJECTED');

-- AlterTable User: Add daily quota fields
ALTER TABLE "User" ADD COLUMN "dailySwipeCount" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "dailyPostCount" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "lastSwipeDate" TIMESTAMP(3),
ADD COLUMN "lastPostDate" TIMESTAMP(3);

-- AlterTable AdoptPost: Add animalName and adoptedAt
ALTER TABLE "AdoptPost" ADD COLUMN "animalName" TEXT NOT NULL DEFAULT '',
ADD COLUMN "adoptedAt" TIMESTAMP(3);

-- CreateTable AdoptRequest
CREATE TABLE "AdoptRequest" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "status" "AdoptRequestStatus" NOT NULL DEFAULT 'PENDING',
    "requesterId" TEXT NOT NULL,
    "postId" TEXT NOT NULL,
    "conversationId" TEXT,

    CONSTRAINT "AdoptRequest_pkey" PRIMARY KEY ("id")
);

-- CreateTable AdoptConversation
CREATE TABLE "AdoptConversation" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "postId" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "adopterId" TEXT NOT NULL,
    "ownerAnonymousName" TEXT NOT NULL,
    "adopterAnonymousName" TEXT NOT NULL,

    CONSTRAINT "AdoptConversation_pkey" PRIMARY KEY ("id")
);

-- CreateTable AdoptMessage
CREATE TABLE "AdoptMessage" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "conversationId" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "readAt" TIMESTAMP(3),

    CONSTRAINT "AdoptMessage_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "AdoptRequest_conversationId_key" ON "AdoptRequest"("conversationId");

-- CreateIndex
CREATE INDEX "AdoptRequest_postId_status_idx" ON "AdoptRequest"("postId", "status");

-- CreateIndex
CREATE INDEX "AdoptRequest_requesterId_status_idx" ON "AdoptRequest"("requesterId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "AdoptRequest_requesterId_postId_key" ON "AdoptRequest"("requesterId", "postId");

-- CreateIndex
CREATE INDEX "AdoptConversation_ownerId_idx" ON "AdoptConversation"("ownerId");

-- CreateIndex
CREATE INDEX "AdoptConversation_adopterId_idx" ON "AdoptConversation"("adopterId");

-- CreateIndex
CREATE UNIQUE INDEX "AdoptConversation_postId_ownerId_adopterId_key" ON "AdoptConversation"("postId", "ownerId", "adopterId");

-- CreateIndex
CREATE INDEX "AdoptMessage_conversationId_createdAt_idx" ON "AdoptMessage"("conversationId", "createdAt");

-- CreateIndex
CREATE INDEX "AdoptMessage_senderId_idx" ON "AdoptMessage"("senderId");

-- AddForeignKey
ALTER TABLE "AdoptRequest" ADD CONSTRAINT "AdoptRequest_requesterId_fkey" FOREIGN KEY ("requesterId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AdoptRequest" ADD CONSTRAINT "AdoptRequest_postId_fkey" FOREIGN KEY ("postId") REFERENCES "AdoptPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AdoptRequest" ADD CONSTRAINT "AdoptRequest_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "AdoptConversation"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AdoptConversation" ADD CONSTRAINT "AdoptConversation_postId_fkey" FOREIGN KEY ("postId") REFERENCES "AdoptPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AdoptConversation" ADD CONSTRAINT "AdoptConversation_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AdoptConversation" ADD CONSTRAINT "AdoptConversation_adopterId_fkey" FOREIGN KEY ("adopterId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AdoptMessage" ADD CONSTRAINT "AdoptMessage_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "AdoptConversation"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AdoptMessage" ADD CONSTRAINT "AdoptMessage_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

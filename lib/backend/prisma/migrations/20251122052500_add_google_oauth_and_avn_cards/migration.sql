-- AlterTable User: Add Google OAuth fields
ALTER TABLE "User" ADD COLUMN "googleId" TEXT;
ALTER TABLE "User" ADD COLUMN "firstName" TEXT;
ALTER TABLE "User" ADD COLUMN "lastName" TEXT;
ALTER TABLE "User" ADD COLUMN "photoUrl" TEXT;

-- AlterTable User: Make password optional for Google users
ALTER TABLE "User" ALTER COLUMN "password" DROP NOT NULL;

-- AlterTable ProviderProfile: Add AVN card fields
ALTER TABLE "ProviderProfile" ADD COLUMN "avnCardFront" TEXT;
ALTER TABLE "ProviderProfile" ADD COLUMN "avnCardBack" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "User_googleId_key" ON "User"("googleId");

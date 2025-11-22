-- AlterTable User: Add Google OAuth fields (IF NOT EXISTS)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='User' AND column_name='googleId') THEN
    ALTER TABLE "User" ADD COLUMN "googleId" TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='User' AND column_name='firstName') THEN
    ALTER TABLE "User" ADD COLUMN "firstName" TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='User' AND column_name='lastName') THEN
    ALTER TABLE "User" ADD COLUMN "lastName" TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='User' AND column_name='photoUrl') THEN
    ALTER TABLE "User" ADD COLUMN "photoUrl" TEXT;
  END IF;
END $$;

-- AlterTable User: Make password optional for Google users
ALTER TABLE "User" ALTER COLUMN "password" DROP NOT NULL;

-- AlterTable ProviderProfile: Add AVN card fields (IF NOT EXISTS)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='ProviderProfile' AND column_name='avnCardFront') THEN
    ALTER TABLE "ProviderProfile" ADD COLUMN "avnCardFront" TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='ProviderProfile' AND column_name='avnCardBack') THEN
    ALTER TABLE "ProviderProfile" ADD COLUMN "avnCardBack" TEXT;
  END IF;
END $$;

-- CreateIndex (IF NOT EXISTS)
CREATE UNIQUE INDEX IF NOT EXISTS "User_googleId_key" ON "User"("googleId");

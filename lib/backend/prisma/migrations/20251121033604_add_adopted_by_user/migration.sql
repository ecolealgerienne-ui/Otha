-- AlterTable
ALTER TABLE "AdoptPost" ADD COLUMN "adoptedById" TEXT;

-- AddForeignKey
ALTER TABLE "AdoptPost" ADD CONSTRAINT "AdoptPost_adoptedById_fkey" FOREIGN KEY ("adoptedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

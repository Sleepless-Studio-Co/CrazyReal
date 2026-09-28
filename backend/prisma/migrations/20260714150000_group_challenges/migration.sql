-- AlterTable
ALTER TABLE "Challenge" ADD COLUMN "conversationId" INTEGER,
ADD COLUMN "endsAt" TIMESTAMP(3);

-- DropIndex
DROP INDEX "Challenge_date_type_key";

-- CreateIndex
CREATE UNIQUE INDEX "Challenge_date_type_conversationId_key" ON "Challenge"("date", "type", "conversationId");

-- AddForeignKey
ALTER TABLE "Challenge" ADD CONSTRAINT "Challenge_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "Conversation"("id") ON DELETE CASCADE ON UPDATE CASCADE;

/*
  Warnings:

  - You are about to drop the column `content` on the `Challenge` table. All the data in the column will be lost.
  - A unique constraint covering the columns `[date,type]` on the table `Challenge` will be added. If there are existing duplicate values, this will fail.

*/
-- CreateEnum
CREATE TYPE "ChallengeType" AS ENUM ('WEEKLY_A', 'WEEKLY_B', 'SPECIAL');

-- AlterTable
ALTER TABLE "Challenge" DROP COLUMN "content",
ADD COLUMN     "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "description" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "title" TEXT NOT NULL DEFAULT 'Global Challenge',
ADD COLUMN     "type" "ChallengeType" NOT NULL DEFAULT 'WEEKLY_A',
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- CreateIndex
CREATE UNIQUE INDEX "Challenge_date_type_key" ON "Challenge"("date", "type");

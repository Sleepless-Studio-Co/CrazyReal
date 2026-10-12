-- CreateEnum
CREATE TYPE "MediaType" AS ENUM ('PHOTO', 'VIDEO');

-- AlterTable
ALTER TABLE "Post" ADD COLUMN "mediaType" "MediaType" NOT NULL DEFAULT 'PHOTO';

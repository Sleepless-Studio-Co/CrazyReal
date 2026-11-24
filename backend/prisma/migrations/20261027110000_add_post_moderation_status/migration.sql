CREATE TYPE "PostModerationStatus" AS ENUM ('PENDING', 'GHOSTED', 'APPROVED', 'REMOVED');
ALTER TABLE "Post" ADD COLUMN "moderationStatus" "PostModerationStatus" NOT NULL DEFAULT 'PENDING';
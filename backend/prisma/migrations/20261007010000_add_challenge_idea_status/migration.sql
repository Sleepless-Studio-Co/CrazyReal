CREATE TYPE "ChallengeIdeaStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

ALTER TABLE "ChallengeIdea" ADD COLUMN "status" "ChallengeIdeaStatus" NOT NULL DEFAULT 'PENDING';

DROP INDEX "ChallengeIdea_createdAt_idx";
CREATE INDEX "ChallengeIdea_status_createdAt_idx" ON "ChallengeIdea"("status", "createdAt");
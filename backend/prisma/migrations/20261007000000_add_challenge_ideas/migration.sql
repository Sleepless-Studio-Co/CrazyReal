CREATE TABLE "ChallengeIdea" (
    "id" SERIAL NOT NULL,
    "content" VARCHAR(500) NOT NULL,
    "userId" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ChallengeIdea_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ChallengeIdea_createdAt_idx" ON "ChallengeIdea"("createdAt");

ALTER TABLE "ChallengeIdea" ADD CONSTRAINT "ChallengeIdea_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
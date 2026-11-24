-- AlterTable
ALTER TABLE "Challenge" ADD COLUMN "latitude" DOUBLE PRECISION,
ADD COLUMN "longitude" DOUBLE PRECISION;

-- CreateTable
CREATE TABLE "ChallengeRegistration" (
    "id" SERIAL NOT NULL,
    "userId" INTEGER NOT NULL,
    "challengeId" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ChallengeRegistration_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ChallengeRegistration_userId_challengeId_key" ON "ChallengeRegistration"("userId", "challengeId");

-- AddForeignKey
ALTER TABLE "ChallengeRegistration" ADD CONSTRAINT "ChallengeRegistration_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChallengeRegistration" ADD CONSTRAINT "ChallengeRegistration_challengeId_fkey" FOREIGN KEY ("challengeId") REFERENCES "Challenge"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateEnum
CREATE TYPE "ParticipantRole" AS ENUM ('ADMIN', 'MEMBER');

-- AlterTable
ALTER TABLE "Participant" ADD COLUMN "role" "ParticipantRole" NOT NULL DEFAULT 'MEMBER';

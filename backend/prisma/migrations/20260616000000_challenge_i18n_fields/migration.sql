-- AlterTable: replace title/description with bilingual fields
ALTER TABLE "Challenge" RENAME COLUMN "title" TO "titleEn";
ALTER TABLE "Challenge" ALTER COLUMN "titleEn" SET DEFAULT 'Global Challenge';

ALTER TABLE "Challenge" RENAME COLUMN "description" TO "descriptionEn";
ALTER TABLE "Challenge" ALTER COLUMN "descriptionEn" SET DEFAULT '';

ALTER TABLE "Challenge" ADD COLUMN "titleFr" TEXT NOT NULL DEFAULT 'Défi global';
ALTER TABLE "Challenge" ADD COLUMN "descriptionFr" TEXT NOT NULL DEFAULT '';

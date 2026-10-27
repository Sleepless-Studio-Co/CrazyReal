ALTER TABLE "Post" ADD COLUMN "isGhosted" BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE "PostReport" (
    "id" SERIAL NOT NULL,
    "userId" INTEGER NOT NULL,
    "postId" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PostReport_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "PostReport_userId_postId_key" ON "PostReport"("userId", "postId");
CREATE INDEX "PostReport_postId_createdAt_idx" ON "PostReport"("postId", "createdAt");
ALTER TABLE "PostReport" ADD CONSTRAINT "PostReport_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "PostReport" ADD CONSTRAINT "PostReport_postId_fkey" FOREIGN KEY ("postId") REFERENCES "Post"("id") ON DELETE CASCADE ON UPDATE CASCADE;
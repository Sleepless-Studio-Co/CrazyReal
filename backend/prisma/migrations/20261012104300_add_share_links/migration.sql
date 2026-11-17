CREATE TABLE "ShareLink" (
    "id" SERIAL NOT NULL,
    "token" TEXT NOT NULL,
    "postId" INTEGER NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ShareLink_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ShareLink_token_key" ON "ShareLink"("token");
CREATE INDEX "ShareLink_token_expiresAt_idx" ON "ShareLink"("token", "expiresAt");

ALTER TABLE "ShareLink" ADD CONSTRAINT "ShareLink_postId_fkey"
FOREIGN KEY ("postId") REFERENCES "Post"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Indexes used by the streak computation and the public profile feed.
CREATE INDEX "Post_userId_createdAt_idx" ON "Post"("userId", "createdAt");
CREATE INDEX "Post_userId_challengeId_idx" ON "Post"("userId", "challengeId");
CREATE INDEX "Challenge_conversationId_date_idx" ON "Challenge"("conversationId", "date");

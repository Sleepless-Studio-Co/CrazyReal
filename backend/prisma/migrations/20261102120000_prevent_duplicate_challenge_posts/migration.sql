DELETE FROM "Post" older
USING "Post" newer
WHERE older."userId" = newer."userId"
	AND older."challengeId" = newer."challengeId"
	AND (
		older."createdAt" > newer."createdAt"
		OR (older."createdAt" = newer."createdAt" AND older."id" > newer."id")
	);

CREATE UNIQUE INDEX IF NOT EXISTS "Post_userId_challengeId_key" ON "Post"("userId", "challengeId");
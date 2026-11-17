ALTER TABLE "User"
ADD COLUMN "notifyGroupMessages" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN "notifyChallengeReminders" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN "notifyFriendRequests" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN "notifyNewChallenges" BOOLEAN NOT NULL DEFAULT true;
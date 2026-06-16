const { PrismaClient, ChallengeType } = require('@prisma/client');

const prisma = new PrismaClient();

function getWeekStart(date = new Date()) {
  const d = new Date(date);
  const day = d.getUTCDay(); // 0 sunday
  const diff = day === 0 ? -6 : 1 - day; // monday as week start
  d.setUTCDate(d.getUTCDate() + diff);
  d.setUTCHours(0, 0, 0, 0);
  return d;
}

async function main() {
  const weekStart = getWeekStart(new Date());

  const fs = require('fs');
  const path = require('path');
  const file = path.join(__dirname, 'challenges.json');

  if (!fs.existsSync(file)) {
    console.warn('⚠️  prisma/challenges.json not found — skipping seed to avoid clearing existing data.');
    return;
  }

  // clear posts and challenges for a clean seed
  await prisma.$transaction([
    prisma.post.deleteMany({}),
    prisma.challenge.deleteMany({}),
  ]);

  const raw = fs.readFileSync(file, 'utf-8');
  const items = JSON.parse(raw);

  // Normalize dates if provided as ISO strings
  const data = items.map((c) => ({
    titleEn: c.titleEn,
    titleFr: c.titleFr,
    descriptionEn: c.descriptionEn || '',
    descriptionFr: c.descriptionFr || '',
    date: c.date ? new Date(c.date) : weekStart,
    type: c.type || ChallengeType.WEEKLY_A,
    isActive: c.isActive !== undefined ? c.isActive : true,
  }));

  if (data.length > 0) {
    await prisma.challenge.createMany({ data });
    console.log(`✅ Seeded ${data.length} challenges from prisma/challenges.json`);
  } else {
    console.log('ℹ️  No challenges found in prisma/challenges.json');
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

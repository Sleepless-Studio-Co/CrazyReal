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
  const middleOfWeek = new Date(weekStart.getTime() + 84 * 60 * 60 * 1000); // +3.5 days

  await prisma.$transaction([
    prisma.post.deleteMany({}),
    prisma.challenge.deleteMany({}),
  ]);

  await prisma.challenge.createMany({
    data: [
      {
        title: 'Global Challenge A',
        description: 'Publie une photo créative de ton quotidien.',
        date: weekStart,
        type: ChallengeType.WEEKLY_A,
        isActive: true,
      },
      {
        title: 'Global Challenge B',
        description: 'Capture un moment drôle avec tes amis.',
        date: middleOfWeek,
        type: ChallengeType.WEEKLY_B,
        isActive: true,
      },
    ],
  });

  console.log('✅ Seeded 2 global challenges for the current week.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

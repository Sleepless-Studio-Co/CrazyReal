// Faux défis géolocalisés autour de Paris pour tester la carte.
// Relançable : remplace les défis de carte qui n'ont encore aucun post.
const { PrismaClient, ChallengeType } = require('@prisma/client');

const prisma = new PrismaClient();
const HOUR = 60 * 60 * 1000;

// startInH < 0 => déjà en cours.
const demo = [
  { title: 'Photo avec la tour Eiffel', description: 'Fais la pose la plus improbable devant la Dame de fer 🗼', latitude: 48.8584, longitude: 2.2945, startInH: -1, durationH: 4 },
  { title: 'Selfie pyramide du Louvre', description: 'Tiens la pointe de la pyramide du bout des doigts 🔺', latitude: 48.8606, longitude: 2.3376, startInH: -3, durationH: 24 },
  { title: 'Danse au Canal Saint-Martin', description: '10 secondes de danse sur une passerelle 💃', latitude: 48.8719, longitude: 2.3656, startInH: -0.5, durationH: 2 },
  { title: 'Lever de soleil au Sacré-Cœur', description: 'Le ciel de Paris depuis les marches de Montmartre 🌅', latitude: 48.8867, longitude: 2.3431, startInH: 2, durationH: 3 },
  { title: 'Pique-nique au Champ-de-Mars', description: 'Le pique-nique le plus chic possible 🧺', latitude: 48.8556, longitude: 2.2986, startInH: 20, durationH: 6 },
  { title: 'Arc de Triomphe en contre-plongée', description: "Allonge-toi et prends l'Arc par en dessous 📸", latitude: 48.8738, longitude: 2.295, startInH: 50, durationH: 12 },
  { title: 'Grimace à Versailles', description: 'Une grimace royale devant le château 👑', latitude: 48.8049, longitude: 2.1204, startInH: 72, durationH: 8 },
];

async function main() {
  const { count } = await prisma.challenge.deleteMany({
    where: { latitude: { not: null }, posts: { none: {} } },
  });
  const now = Date.now();
  await prisma.challenge.createMany({
    data: demo.map(({ startInH, durationH, ...c }) => {
      const date = new Date(now + startInH * HOUR);
      return {
        ...c,
        type: ChallengeType.SPECIAL,
        date,
        endsAt: new Date(date.getTime() + durationH * HOUR),
      };
    }),
  });
  console.log(`🗺️  ${demo.length} défis de carte créés (${count} anciens supprimés)`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

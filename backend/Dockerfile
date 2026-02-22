# Utiliser une image Node.js légère
FROM node:20-alpine

# Créer et définir le dossier de travail dans le conteneur
WORKDIR /app

# Copier uniquement les fichiers de dépendances en premier (optimisation du cache)
COPY package*.json ./

# Installer les dépendances
RUN npm install

# Copier le reste du code source
COPY . .

# Exposer le port de ton backend (généralement 3000 avec NestJS)
EXPOSE 3000

# Commande par défaut pour lancer le serveur en mode dev
CMD ["npm", "run", "start:dev"]
# CrazyReal

Application mobile de réseau social autour de **défis photo** : répondre au challenge du moment, consulter le fil de publications, gérer ses amis et échanger en messagerie instantanée.

Projet **EIP** (Epitech) — monorepo **Flutter** (client) + **NestJS** (API).

---

## Table des matières

- [Fonctionnalités](#fonctionnalités)
- [Stack technique](#stack-technique)
- [Architecture du dépôt](#architecture-du-dépôt)
- [Prérequis](#prérequis)
- [Démarrage rapide](#démarrage-rapide)
- [Configuration](#configuration)
- [Backend (API)](#backend-api)
- [Application mobile](#application-mobile)
- [API REST (aperçu)](#api-rest-aperçu)
- [Messagerie temps réel](#messagerie-temps-réel)
- [Base de données](#base-de-données)
- [Tests et qualité](#tests-et-qualité)
- [CI / CD](#ci--cd)
- [Dépannage](#dépannage)
- [Licence](#licence)

---

## Fonctionnalités

| Domaine | Description |
|--------|-------------|
| **Challenges** | Défis hebdomadaires et spéciaux, actifs sur une fenêtre temporelle définie |
| **Publications** | Prise de photo via la caméra, upload lié au challenge en cours, fil d’actualité |
| **Comptes** | Inscription, connexion JWT (access + refresh), profil et avatars |
| **Amis** | Demandes, acceptation, liste d’amis |
| **Chat** | Conversations 1-à-1 et groupes, messages via REST + notifications WebSocket |
| **i18n** | Interface mobile FR / EN ; messages API localisés (EN par défaut) |

---

## Stack technique

| Couche | Technologies |
|--------|----------------|
| **Mobile** | Flutter 3.x, Dart 3.5+, `http`, `socket_io_client`, `camera`, `flutter_dotenv` |
| **Backend** | NestJS 11, Prisma 6, PostgreSQL 15, Passport JWT, Socket.io |
| **Outils** | Docker Compose, Swagger, semantic-release (tags) |

---

## Architecture du dépôt

```
CrazyReal/
├── mobile/                 # Application Flutter (Android, iOS, Web, desktop)
│   ├── lib/                # UI, services, l10n
│   └── .env.example        # URL de l'API
├── backend/                # API NestJS
│   ├── src/                # Modules auth, users, friends, chat, posts/challenges
│   ├── prisma/             # Schéma, migrations, seed
│   ├── docker-compose.yml  # API + PostgreSQL + pgAdmin
│   └── .env.example
└── .github/workflows/      # CI (build backend + APK Android)
```

---

## Prérequis

### Backend (Docker — recommandé)

- [Docker](https://docs.docker.com/get-docker/) et Docker Compose v2

### Backend (installation locale)

- [Node.js](https://nodejs.org/) **20.x**
- [PostgreSQL](https://www.postgresql.org/) **15+**

### Mobile

- [Flutter SDK](https://docs.flutter.dev/get-started/install) **stable** (≥ 3.5, CI : 3.41.2)
- Pour Android : JDK 17, Android SDK
- Pour iOS (macOS uniquement) : Xcode

---

## Démarrage rapide

### 1. Cloner le dépôt

```bash
git clone git@github.com:Sleepless-Studio-Co/CrazyReal.git CrazyReal
cd CrazyReal
```

### 2. Lancer le backend

```bash
cd backend
cp .env.example .env
# Éditer .env (JWT_SECRET obligatoire en local hors Docker)
docker compose up --build
```

L’API est disponible sur **http://localhost:3000**.  
Documentation Swagger : **http://localhost:3000/api**

### 3. Lancer l’application mobile

```bash
cd mobile
cp .env.example .env
# Définir API_BASE_URL=http://<IP-machine>:3000
# Sur émulateur Android : souvent http://10.0.2.2:3000
flutter pub get
flutter run
```

> **Note :** la caméra n’est pas disponible sur toutes les cibles (ex. certaines builds Web). Privilégier un appareil physique ou un émulateur Android/iOS pour la création de posts.

---

## Configuration

### Backend — variables d’environnement

Fichier : `backend/.env` (voir `backend/.env.example`).

| Variable | Description | Exemple |
|----------|-------------|---------|
| `DATABASE_URL` | Connexion PostgreSQL (Prisma) | `postgresql://user:pass@localhost:5432/crazydb` |
| `API_HOST` | Hôte d’écoute | `0.0.0.0` |
| `API_PORT` | Port (informatif ; l’app écoute sur 3000 dans `main.ts`) | `3000` |
| `JWT_SECRET` | Secret de signature JWT | Générer avec `openssl rand -base64 32` |
| `JWT_ACCESS_EXPIRATION` | Durée du token d’accès | `15m` |
| `JWT_REFRESH_EXPIRATION` | Durée du refresh token | `30d` |
| `BOOTSTRAP_ADMIN` | Créer un compte admin au démarrage | `true` / absent |
| `BOOTSTRAP_ADMIN_EMAIL` | Email admin (si bootstrap actif) | `admin@example.com` |
| `BOOTSTRAP_ADMIN_PASSWORD` | Mot de passe admin | *(à définir)* |
| `BOOTSTRAP_ADMIN_USERNAME` | Pseudo admin | `admin` |

Avec **Docker Compose**, `DATABASE_URL` est déjà injectée :

`postgresql://crazyuser:crazypassword@db:5432/crazydb?schema=public`

**pgAdmin** (optionnel) : http://localhost:5050 — `admin@crazyreal.com` / `admin`

### Mobile — variables d’environnement

Fichier : `mobile/.env` (voir `mobile/.env.example`).

| Variable | Description |
|----------|-------------|
| `API_BASE_URL` | URL de base de l’API (sans slash final) |

Exemples :

```env
# Machine locale
API_BASE_URL=http://localhost:3000

# Émulateur Android → hôte de la machine
API_BASE_URL=http://10.0.2.2:3000

# Appareil physique (même réseau Wi‑Fi)
API_BASE_URL=http://192.168.1.42:3000
```

---

## Backend (API)

### Docker Compose (recommandé)

```bash
cd backend
docker compose up --build
```

Services :

| Service | Port | Rôle |
|---------|------|------|
| `api` | 3000 | API NestJS (hot reload via volume) |
| `db` | 5432 | PostgreSQL |
| `pgadmin` | 5050 | Interface d’administration BDD |

Arrêt et suppression des volumes (réinitialise la BDD) :

```bash
docker compose down -v
```

### Installation locale (sans Docker)

```bash
cd backend
cp .env.example .env
npm ci
npx prisma migrate deploy
npm run db:seed          # optionnel : challenges de la semaine
npm run start:dev
```

### Commandes utiles

```bash
npm run build            # Compilation TypeScript
npm run start:prod       # Production (dist/)
npm run lint             # ESLint
npm run test             # Tests unitaires Jest
npm run test:e2e         # Tests e2e
```

Les fichiers uploadés (photos de posts) sont servis sous `/uploads/`.

---

## Application mobile

```bash
cd mobile
flutter pub get
flutter gen-l10n          # si les traductions ne sont pas générées
flutter run               # choisir un device : flutter devices
```

Build release Android :

```bash
flutter build apk --release
```

L’APK se trouve dans `mobile/build/app/outputs/flutter-apk/app-release.apk`.

### Navigation principale

| Onglet | Écran |
|--------|--------|
| Accueil | Fil des publications |
| Amis | Demandes et liste d’amis |
| Nouveau | Caméra + envoi pour le challenge actif |
| Paramètres | Préférences |
| Compte | Profil, avatar, déconnexion |

---

## API REST (aperçu)

Authentification : en-tête `Authorization: Bearer <access_token>` pour les routes protégées.

Documentation interactive : **GET** `/api` (Swagger).

### Authentification — `/auth`

| Méthode | Route | Auth | Description |
|---------|-------|------|-------------|
| `POST` | `/auth/register` | Non | Inscription (`email`, `password`, `username`) |
| `POST` | `/auth/login` | Non | Connexion |
| `POST` | `/auth/refresh` | Non | Renouvellement du token |
| `POST` | `/auth/logout` | Oui | Révocation du refresh token |
| `GET` | `/auth/me` | Oui | Profil courant |
| `PATCH` | `/auth/me` | Oui | Mise à jour email / username |

### Challenges & posts

| Méthode | Route | Auth | Description |
|---------|-------|------|-------------|
| `GET` | `/challenge/current` | Oui | Challenge actif |
| `POST` | `/posts` | Oui | Upload photo (`multipart/form-data`, champ `file`) |
| `GET` | `/posts` | Oui | Liste des posts (avec utilisateur) |

### Amis — `/friends`

| Méthode | Route | Description |
|---------|-------|-------------|
| `POST` | `/friends/request/:username` | Envoyer une demande |
| `PATCH` | `/friends/accept/:requestId` | Accepter une demande |
| `GET` | `/friends` | Liste des amis |
| `GET` | `/friends/requests` | Demandes en attente |

### Chat — `/chat`

| Méthode | Route | Description |
|---------|-------|-------------|
| `GET` | `/chat` | Conversations de l’utilisateur |
| `POST` | `/chat/group` | Créer un groupe (`name`, `members[]`) |
| `POST` | `/chat/:id/messages` | Envoyer un message |
| `GET` | `/chat/:id/messages` | Historique des messages |

### Utilisateurs — `/users`

Routes protégées pour le profil et la gestion des avatars (sélection prédéfinie ou upload).

---

## Messagerie temps réel

Le client se connecte via **Socket.io** sur la même origine que `API_BASE_URL`, en passant le JWT d'accès dans `auth.token` lors du handshake (sinon le `WsJwtAuthGuard` refuse la connexion et aucun événement n'est jamais reçu).

| Événement (client → serveur) | Description |
|------------------------------|-------------|
| `joinRoom` | Rejoindre une conversation (`conversationId`) |
| `typing` | Signale que l'utilisateur est en train d'écrire (`conversationId`) |
| `stopTyping` | Signale l'arrêt de la saisie (`conversationId`) |

| Événement (serveur → client) | Description |
|------------------------------|-------------|
| `newMessage` | Nouveau message dans la room |
| `joinRoomError` | Erreur d’authentification ou d’accès |
| `userTyping` | Un autre participant est en train d'écrire (`userId`, `username`) |
| `userStoppedTyping` | Un autre participant a arrêté d'écrire (`userId`, `username`) |

L’authentification WebSocket utilise le JWT (guard `WsJwtAuthGuard`).

---

## Base de données

Modèle principal (Prisma) :

- **User** — compte, avatars, relations
- **Challenge** / **Post** — défis et publications photo
- **Friendship** — statuts `PENDING`, `ACCEPTED`, `BLOCKED`
- **Conversation** / **Participant** / **Message** — messagerie
- **RefreshToken** — sessions persistantes

Commandes :

```bash
cd backend
npx prisma migrate deploy    # appliquer les migrations
npx prisma studio            # interface graphique
npm run db:seed              # challenges hebdomadaires de démo
```

Types de challenge : `WEEKLY_A`, `WEEKLY_B`, `SPECIAL` (durées actives : 84 h / 84 h / 24 h).

---

## Tests et qualité

### Backend

```bash
cd backend
npm run test
npm run test:e2e
npm run lint
```

### Mobile

```bash
cd mobile
flutter analyze
flutter test
```

---

## CI / CD

Workflow GitHub Actions : `.github/workflows/ci.yml`

| Job | Déclencheur | Action |
|-----|-------------|--------|
| **Build Backend** | Modifications dans `backend/` | `npm ci` + `npm run build` |
| **Build Mobile (Android)** | Modifications dans `mobile/` | APK release en artifact |
| **Semantic Release** | Push sur `main` | Versioning automatique |
| **Upload Release Assets** | Tags `v*.*.*` | APK attaché à la release GitHub |

Les changements uniquement sur des fichiers `.md` ne déclenchent pas la CI (`paths-ignore`).

---

## Dépannage

| Problème | Piste de résolution |
|----------|-------------------|
| L’app mobile ne joint pas l’API | Vérifier `API_BASE_URL`, pare-feu, même réseau ; sur Android utiliser `10.0.2.2` pour localhost |
| `401 Unauthorized` | Token expiré — se reconnecter ; vérifier `JWT_SECRET` identique entre redémarrages |
| Aucun challenge actif | Lancer `npm run db:seed` ou créer un challenge actif en BDD |
| Erreur Prisma au démarrage Docker | Attendre que PostgreSQL soit prêt ; `docker compose down -v` puis relancer |
| Caméra indisponible | Tester sur mobile physique ou émulateur, pas sur Web |

---

## Licence

Projet **privé** — `UNLICENSED` (voir `backend/package.json`).  
Usage, distribution et modification soumis aux règles de votre équipe / établissement EIP.

---

## Équipe & contribution

1. Créer une branche depuis `main`
2. Commiter avec des messages clairs (Conventional Commits recommandé pour semantic-release)
3. Ouvrir une pull request — la CI valide les parties modifiées (backend et/ou mobile)

Pour signaler un bug ou proposer une évolution, utiliser les modèles d’issues dans `.github/ISSUE_TEMPLATE/`.

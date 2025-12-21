# ---------- base (Debian, pas Alpine) ----------
FROM node:20-bookworm-slim AS base
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    openssl \
 && rm -rf /var/lib/apt/lists/*

# ---------- deps (avec dev pour builder) ----------
FROM base AS deps
WORKDIR /app

# Copier package.json et package-lock.json pour cache layer
COPY package*.json ./
RUN npm config set legacy-peer-deps true
RUN npm ci

# Prisma: copier schema et générer client (version 6.19.0 du package.json)
COPY prisma ./prisma
RUN npx prisma generate

# Playwright: installer Chromium + dépendances système UNE SEULE FOIS
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN npx --yes playwright@1.56.1 install --with-deps chromium

# ---------- build ----------
FROM deps AS builder
WORKDIR /app
# Copier tout le code source
COPY . .
# Build NestJS
RUN npx nest build

# ---------- prod-deps (runtime sans dev) ----------
FROM base AS prod-deps
WORKDIR /app
COPY package*.json ./
RUN npm config set legacy-peer-deps true
RUN npm ci --omit=dev

# Prisma: générer client pour production (même version 6.19.0)
COPY prisma ./prisma
RUN npx prisma generate

# ---------- run ----------
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production

# Configuration Playwright: utiliser les navigateurs pré-installés
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

# Copier node_modules de production (sans devDependencies)
COPY --from=prod-deps /app/node_modules ./node_modules

# Copier le build NestJS
COPY --from=builder /app/dist ./dist

# Copier Prisma schema (nécessaire pour les migrations)
COPY --from=builder /app/prisma ./prisma

# Copier les navigateurs Playwright déjà installés depuis deps
COPY --from=deps /ms-playwright /ms-playwright

# Copier package.json pour info de version
COPY package*.json ./

# Copier le script de démarrage
COPY --from=builder /app/start.sh ./start.sh
RUN chmod +x ./start.sh

EXPOSE 3000 5555

# Lancer le script de démarrage
CMD ["./start.sh"]

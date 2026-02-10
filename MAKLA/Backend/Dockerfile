# ---------- base (Debian, pas Alpine) ----------
FROM node:20-bookworm-slim AS base
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    openssl \
    curl \
 && rm -rf /var/lib/apt/lists/*

# ---------- deps (avec dev pour builder) ----------
FROM base AS deps
WORKDIR /app

# Copier package.json et package-lock.json pour cache layer
COPY package*.json ./
RUN npm config set legacy-peer-deps true
RUN npm ci

# Prisma: copier schema et générer client
COPY prisma ./prisma
RUN npx prisma generate

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

# Prisma: générer client pour production
COPY prisma ./prisma
RUN npx prisma generate

# ---------- run ----------
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production

# Copier node_modules de production (sans devDependencies)
COPY --from=prod-deps /app/node_modules ./node_modules

# Copier le build NestJS
COPY --from=builder /app/dist ./dist

# Copier Prisma schema (nécessaire pour les migrations)
COPY --from=builder /app/prisma ./prisma

# Copier package.json pour info de version
COPY package*.json ./

# Copier le script de démarrage
COPY --from=builder /app/start.sh ./start.sh
RUN chmod +x ./start.sh

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000 5555

# Lancer le script de démarrage
CMD ["./start.sh"]

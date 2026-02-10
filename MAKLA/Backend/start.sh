#!/bin/sh
set -e

echo "🔄 Running Prisma migrations..."
npx prisma migrate deploy

echo "🚀 Starting Prisma Studio in background..."
npx prisma studio --hostname 0.0.0.0 > /dev/null 2>&1 &

echo "🎯 Starting NestJS application..."
exec node dist/src/main.js

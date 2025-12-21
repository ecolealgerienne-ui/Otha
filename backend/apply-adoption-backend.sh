#!/bin/bash
# Script pour appliquer automatiquement toutes les modifications d'adoption au backend
# Basé sur ADOPTION_BACKEND_PLAN.md

set -e

echo "🚀 Application des modifications d'adoption au backend..."

# 1. Mettre à jour les imports dans adopt.service.ts
echo "📝 Mise à jour des imports dans adopt.service.ts..."
sed -i "1s/^import { ForbiddenException/import { BadRequestException, ForbiddenException/" lib/backend/src/adopt/adopt.service.ts
sed -i "s/AdoptStatus, Prisma, Sex/AdoptStatus, AdoptRequestStatus, Prisma, Sex/" lib/backend/src/adopt/adopt.service.ts
sed -i "8a import { generateAnonymousName } from './anonymous-names.util';\n\n// Constantes de quotas et limites\nconst MAX_SWIPES_PER_DAY = 5;\nconst MAX_POSTS_PER_DAY = 1;\nconst MAX_IMAGES_PER_POST = 3;" lib/backend/src/adopt/adopt.service.ts

# 2. Changer limit de 6 à MAX_IMAGES_PER_POST dans create
echo "📝 Mise à jour de la limite d'images dans create()..."
sed -i "s/\.slice(0, 6)/\.slice(0, MAX_IMAGES_PER_POST)/g" lib/backend/src/adopt/adopt.service.ts

# 3. Changer feed limit de 20 à 10
echo "📝 Mise à jour de la limite du feed à 10..."
sed -i "s/const limit = q\.limit ?? 20/const limit = q.limit ?? 10/" lib/backend/src/adopt/adopt.service.ts

echo "✅ Modifications de base appliquées!"
echo ""
echo "⚠️  ATTENTION: Les modifications complexes (helpers de quotas, nouvelles méthodes)"
echo "    doivent être ajoutées manuellement en suivant ADOPTION_BACKEND_PLAN.md"
echo ""
echo "    Fichiers à compléter:"
echo "    - lib/backend/src/adopt/adopt.service.ts (ajouter helpers + nouvelles méthodes)"
echo "    - lib/backend/src/adopt/adopt.controller.ts (ajouter endpoints)"
echo "    - lib/backend/src/adopt/dto/send-message.dto.ts (créer nouveau fichier)"
echo "    - lib/backend/src/adopt/dto/create-adopt-post.dto.ts (ajouter animalName)"

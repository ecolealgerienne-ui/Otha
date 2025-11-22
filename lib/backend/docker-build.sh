#!/bin/bash

# Script de build Docker optimisé pour VPS
# Usage: ./docker-build.sh [clean|rebuild]

IMAGE_NAME="vethome-backend"
IMAGE_TAG="latest"

echo "🐳 Construction de l'image Docker ${IMAGE_NAME}:${IMAGE_TAG}"

# Si argument "clean", nettoyer les anciennes images et cache
if [ "$1" = "clean" ]; then
    echo "🧹 Nettoyage des anciennes images..."
    docker system prune -af --volumes
    docker builder prune -af
fi

# Si argument "rebuild", forcer un rebuild complet sans cache
if [ "$1" = "rebuild" ]; then
    echo "🔨 Rebuild complet sans cache..."
    DOCKER_BUILDKIT=1 docker build \
        --no-cache \
        --progress=plain \
        -t ${IMAGE_NAME}:${IMAGE_TAG} \
        .
else
    # Build normal avec cache
    echo "🚀 Build avec cache..."
    DOCKER_BUILDKIT=1 docker build \
        --progress=plain \
        -t ${IMAGE_NAME}:${IMAGE_TAG} \
        .
fi

# Vérifier le résultat
if [ $? -eq 0 ]; then
    echo "✅ Image construite avec succès!"
    echo ""
    echo "Pour lancer le conteneur:"
    echo "  docker run -d -p 3000:3000 --name vethome-api ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo "Pour voir les logs:"
    echo "  docker logs -f vethome-api"
else
    echo "❌ Erreur lors de la construction de l'image"
    exit 1
fi

#!/bin/bash
set -e

IMAGE=$1

if [ -z "$IMAGE" ]; then
    echo "Usage: ./sign.sh <image>"
    exit 1
fi

echo "=== Installation Cosign si absent ==="
if ! command -v cosign &>/dev/null; then
    curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 \
        -o /usr/local/bin/cosign
    chmod +x /usr/local/bin/cosign
    echo "Cosign installé"
fi

echo "=== Génération clé Cosign si absente ==="
if [ ! -f cosign.key ]; then
    COSIGN_PASSWORD="" cosign generate-key-pair
    echo "Clés générées"
else
    echo "Clés déjà existantes"
fi

echo "=== Login Harbor avant signature ==="
if [ -n "${HARBOR_USER}" ] && [ -n "${HARBOR_PASS}" ]; then
    echo "${HARBOR_PASS}" | docker login "${HARBOR_HOST:-localhost:8081}" \
        -u "${HARBOR_USER}" --password-stdin
fi

echo "=== Signature de l'image : $IMAGE ==="
COSIGN_PASSWORD="" cosign sign \
    --key cosign.key \
    --allow-insecure-registry \
    --yes \
    "$IMAGE"

echo "Image signée avec succès : $IMAGE"
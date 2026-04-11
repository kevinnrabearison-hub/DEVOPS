#!/bin/bash
set -e

IMAGE=$1

if [ -z "$IMAGE" ]; then
    echo "Usage: ./verify.sh <image>"
    exit 1
fi

echo "=== Vérification signature Cosign : $IMAGE ==="

if [ ! -f cosign.pub ]; then
    echo "ERREUR : cosign.pub introuvable"
    exit 1
fi

if ! command -v cosign &>/dev/null; then
    curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 \
        -o /usr/local/bin/cosign
    chmod +x /usr/local/bin/cosign
fi

COSIGN_PASSWORD="" cosign verify \
    --key cosign.pub \
    --allow-insecure-registry \
    "$IMAGE"

echo "Signature vérifiée avec succès : $IMAGE"
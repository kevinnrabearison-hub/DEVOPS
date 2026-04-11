#!/bin/bash
set -e

echo "=== Génération clés Cosign (si absentes) ==="

if ! command -v cosign &>/dev/null; then
    echo "Installation de Cosign..."
    curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 \
        -o /usr/local/bin/cosign
    chmod +x /usr/local/bin/cosign
fi

if [ ! -f cosign.key ]; then
    COSIGN_PASSWORD="" cosign generate-key-pair
    echo "Clés générées : cosign.key + cosign.pub"
else
    echo "Clés déjà existantes"
fi
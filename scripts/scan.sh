#!/bin/bash
set -e

echo "=== Génération clés Cosign (si absentes) ==="

if [ ! -f cosign.key ]; then
    cosign generate-key-pair
else
    echo "Clés déjà existantes"
fi
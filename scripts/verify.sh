#!/bin/bash
set -e

IMAGE=$1

echo "=== Vérification image ==="

cosign verify --key cosign.pub $IMAGE
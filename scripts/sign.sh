#!/bin/bash
set -e

IMAGE=$1

echo "=== Signature image ==="

cosign sign --key cosign.key $IMAGE
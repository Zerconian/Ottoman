#!/bin/bash
# Build the Ottoman bootc image with podman (no root needed). Prints pwd and branch first (gate rule).
set -euo pipefail
cd "$(dirname "$0")/.."
echo "pwd: $(pwd)  branch: $(git rev-parse --abbrev-ref HEAD)  head: $(git rev-parse --short HEAD)"
TAG=${1:-localhost/ottoman:dev}
nice -n 19 ionice -c3 podman build --pull=newer -t "$TAG" -f image/Containerfile .
podman image inspect "$TAG" --format 'built {{.Created}} size {{.Size}} bytes'

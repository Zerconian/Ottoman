#!/bin/bash
# Build the Ottoman bootc image with podman (no root needed). Prints pwd and branch first (gate rule).
set -euo pipefail
cd "$(dirname "$0")/.."
echo "pwd: $(pwd)  branch: $(git rev-parse --abbrev-ref HEAD)  head: $(git rev-parse --short HEAD)"
TAG=${1:-localhost/ottoman:dev}
DEV=${DEV:-1}            # DEV=0 for a release image (no insecure dev registry baked in)
nice -n 19 ionice -c3 podman build --pull=newer --build-arg DEV="$DEV" -t "$TAG" -f image/Containerfile .
podman image inspect "$TAG" --format 'built {{.Created}} size {{.Size}} bytes'

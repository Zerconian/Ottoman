#!/bin/bash
# Compile ottoman-shell in the builder container (no Qt devel on the host needed). Output: build/shell/.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "pwd: $(pwd)  branch: $(git rev-parse --abbrev-ref HEAD)  head: $(git rev-parse --short HEAD)"
podman image exists localhost/ottoman-builder:44 || podman build -q -t localhost/ottoman-builder:44 -f image/Containerfile.builder image/
mkdir -p build/shell
podman run --rm -v "$(pwd)/shell":/src:ro,Z -v "$(pwd)/build/shell":/out:Z localhost/ottoman-builder:44 \
  bash -c 'cmake -S /src -B /out -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null && cmake --build /out && ls -la /out/ottoman-shell'

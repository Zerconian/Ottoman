#!/bin/bash
# Compile ottoman-shell in the builder container (no Qt devel on the host needed). Output: build/shell/.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "pwd: $(pwd)  branch: $(git rev-parse --abbrev-ref HEAD)  head: $(git rev-parse --short HEAD)"
podman image exists localhost/ottoman-builder:44 || podman build -q -t localhost/ottoman-builder:44 -f image/Containerfile.builder image/
mkdir -p build/shell
podman run --rm -v "$(pwd)/shell":/src:ro,Z -v "$(pwd)/build/shell":/out:Z localhost/ottoman-builder:44 \
  bash -c 'cmake -S /src -B /out -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null && cmake --build /out && ls -la /out/ottoman-shell'
# Load check: run the bare binary ALONE (no build tree beside it) offscreen. Exit 124 = QML module loaded and
# the app ran until timeout; 1 = module not found. Armed 2026-11-03: the RESOURCE_PREFIX / variant exits 1.
podman run --rm -v "$(pwd)/build/shell":/out:ro,Z localhost/ottoman-builder:44 \
  bash -c 'mkdir /t && cp /out/ottoman-shell /t/ && cd / && QT_QPA_PLATFORM=offscreen timeout 4 /t/ottoman-shell >/dev/null 2>&1; rc=$?; [ $rc -eq 124 ] && echo "load check: ok" || { echo "load check FAILED (exit $rc)"; exit 1; }'

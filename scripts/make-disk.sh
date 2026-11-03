#!/bin/bash
# Turn the built bootc image into a qcow2 disk with bootc-image-builder (bib).
# bib needs root podman (loop devices, privileged mounts): run as `sudo ./scripts/make-disk.sh`.
# The rootless image store is not visible to root podman, so the image is copied across first.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "pwd: $(pwd)  branch: $(git rev-parse --abbrev-ref HEAD)  head: $(git rev-parse --short HEAD)"
IMG=${1:-localhost/ottoman:dev}
OUT=${2:-$(pwd)/build/disk}
TYPE=${TYPE:-qcow2}            # qcow2 | anaconda-iso | raw
CONFIG=${CONFIG:-image/bib-config.dev.toml}   # CONFIG= (empty) for a clean disk
ROOTFS=${ROOTFS:-xfs}
if [ "$(id -u)" -ne 0 ]; then echo "run with sudo (bib needs privileged podman)" >&2; exit 2; fi
mkdir -p "$OUT"
# Always copy the rootless-built image into root's store: root's copy goes stale otherwise
# (2026-11-02: the second dev disk silently reused the first run's image and lacked the fixes).
SRC_USER=${SUDO_USER:-zerc}
SRC_ID=$(sudo -u "$SRC_USER" podman image inspect "$IMG" --format '{{.Id}}')
if [ "$(podman image inspect "$IMG" --format '{{.Id}}' 2>/dev/null)" != "$SRC_ID" ]; then
  echo "copying $IMG ($SRC_ID) from $SRC_USER's rootless store"
  sudo -u "$SRC_USER" podman save "$IMG" | podman load >/dev/null
fi
echo "building from image id $(podman image inspect "$IMG" --format '{{.Id}}' | cut -c1-12)"
CFG_ARGS=(); if [ -n "$CONFIG" ]; then CFG_ARGS=(-v "$(realpath "$CONFIG")":/config.toml:ro); echo "customizations: $CONFIG"; fi
podman run --rm --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  "${CFG_ARGS[@]}" \
  -v "$OUT":/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type "$TYPE" --rootfs "$ROOTFS" --local "$IMG"
# bib writes as root; hand the result back to the invoking user so vm-run.sh can make overlays beside it.
chown -R "$SRC_USER:" "$(pwd)/build"
ls -la "$OUT"/*/ 2>/dev/null || ls -la "$OUT"

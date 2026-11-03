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
ROOTFS=${ROOTFS:-xfs}
if [ "$(id -u)" -ne 0 ]; then echo "run with sudo (bib needs privileged podman)" >&2; exit 2; fi
mkdir -p "$OUT"
# Copy the rootless-built image into root's store (idempotent; skipped if already identical).
SRC_USER=${SUDO_USER:-zerc}
podman image exists "$IMG" || \
  podman pull "containers-storage:[$(getent passwd "$SRC_USER" | cut -d: -f6)/.local/share/containers/storage]$IMG" 2>/dev/null || \
  { echo "copying $IMG from $SRC_USER's rootless store"; sudo -u "$SRC_USER" podman save "$IMG" | podman load; }
podman run --rm --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  -v "$OUT":/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type "$TYPE" --rootfs "$ROOTFS" --local "$IMG"
ls -la "$OUT"/*/ 2>/dev/null || ls -la "$OUT"

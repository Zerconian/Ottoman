#!/bin/bash
# Turn the built bootc image into a qcow2 disk with bootc-image-builder (bib).
# bib needs root podman (loop devices, privileged mounts): run as `sudo ./scripts/make-disk.sh`.
# The rootless image store is not visible to root podman, so the image is copied across first.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "pwd: $(pwd)  branch: $(git rev-parse --abbrev-ref HEAD)  head: $(git rev-parse --short HEAD)"
IMG=${1:-localhost/ottoman:dev}
OUT=${2:-$(pwd)/build/disk}
# The installed system keeps the image NAME it was built from as its update reference. A disk built from
# localhost/ottoman:dev can never update (found 2026-11-03). Build from the registry name instead: the dev
# registry on the build host's LAN address (DEV_REGISTRY_HOST), reachable from QEMU user networking and from the Tiny alike.
. ./scripts/dev-env.sh
IMAGE_REF=${IMAGE_REF:-$DEV_REGISTRY_HOST:18821/ottoman:dev}
TYPE=${TYPE:-qcow2}            # qcow2 | anaconda-iso | raw
# bib applies customizations.files only on the disk path; the ISO path takes [customizations.installer] instead.
# The dev customizations are templates: the login user and key come from the dev env (never from git).
mkdir -p build; for t in image/bib-config.dev*.toml.in; do sed -e "s|@DEV_USER@|$DEV_USER|" -e "s|@DEV_SSH_KEY@|$DEV_SSH_KEY|" "$t" > "build/$(basename "${t%.in}")"; done
if [ "$TYPE" = anaconda-iso ]; then CONFIG=${CONFIG-build/bib-config.dev-iso.toml}; else CONFIG=${CONFIG-build/bib-config.dev.toml}; fi   # CONFIG= (empty) for a clean build
ROOTFS=${ROOTFS:-xfs}
if [ "$(id -u)" -ne 0 ]; then echo "run with sudo (bib needs privileged podman)" >&2; exit 2; fi
mkdir -p "$OUT"
# Always copy the rootless-built image into root's store: root's copy goes stale otherwise
# (2026-11-02: the second dev disk silently reused the first run's image and lacked the fixes).
SRC_USER=${SUDO_USER:?run via sudo so the rootless image store can be found}
SRC_ID=$(sudo -u "$SRC_USER" podman image inspect "$IMG" --format '{{.Id}}')
if [ "$(podman image inspect "$IMG" --format '{{.Id}}' 2>/dev/null)" != "$SRC_ID" ]; then
  echo "copying $IMG ($SRC_ID) from $SRC_USER's rootless store"
  sudo -u "$SRC_USER" podman save "$IMG" | podman load >/dev/null
fi
podman tag "$IMG" "$IMAGE_REF"
IMG=$IMAGE_REF
echo "building from image id $(podman image inspect "$IMG" --format '{{.Id}}' | cut -c1-12) as $IMG"
CFG_ARGS=(); if [ -n "$CONFIG" ]; then CFG_ARGS=(-v "$(realpath "$CONFIG")":/config.toml:ro); echo "customizations: $CONFIG"; fi
podman run --rm --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  "${CFG_ARGS[@]}" \
  -v "$OUT":/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type "$TYPE" --rootfs "$ROOTFS" --local "$IMG"
# Installer ISOs get the Ottoman treatment (short countdown, splash, anaconda sidebar): scripts/brand-iso.sh.
[ "$TYPE" = anaconda-iso ] && ./scripts/brand-iso.sh "$OUT/bootiso/install.iso"
# bib writes as root; hand the result back to the invoking user so vm-run.sh can make overlays beside it.
chown -R "$SRC_USER:" "$(pwd)/build"
ls -la "$OUT"/*/ 2>/dev/null || ls -la "$OUT"

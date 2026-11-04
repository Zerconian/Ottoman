#!/bin/bash
# Manual release (zerc 2026-11-04: Ottoman is public on GitHub; the image lives on ghcr, the installer on GitHub Releases):
#   1. DEV=0 image (no dev user rule, no insecure dev registry) tagged :stable and :<date>-<sha> (immutable)
#   2. push both to $REG (needs a prior `podman login ghcr.io`)
#   3. the public installer: netinstall ISO that pulls :stable during the install (~1.2 GB, no root needed)
#   4. OFFLINE=1 also builds the 2.8 GiB offline ISO that embeds the image (local installs only; the make-disk sudo rule)
#   5. a line in docs/RELEASES.md with digest + ISO sha256, committed and pushed
# GitHub Actions does 1-3 on a release-* tag or a manual run (.github/workflows/build.yml); this is the hand-run path.
# Refuses a dirty tree or an unpushed main. Prints pwd/branch/head first (gate rule). ~10 min on the build host.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "pwd: $(pwd)  branch: $(git rev-parse --abbrev-ref HEAD)  head: $(git rev-parse --short HEAD)"
REG=${REG:-ghcr.io/zerconian/ottoman}
git diff --quiet && git diff --cached --quiet || { echo "release: working tree is dirty; commit first" >&2; exit 2; }
git fetch -q origin && [ -z "$(git log origin/main..HEAD --oneline)" ] || { echo "release: unpushed commits on main; push first" >&2; exit 2; }
SHA=$(git rev-parse --short HEAD); TAG=$(date -u +%Y%m%d)-$SHA
podman login --get-login "${REG%%/*}" >/dev/null 2>&1 || { echo "release: not logged in: podman login ${REG%%/*} -u <github user> (token with write:packages)" >&2; exit 2; }
echo "== 1. build DEV=0 image"
DEV=0 ./scripts/build-image.sh localhost/ottoman:release | tail -1
podman run --rm localhost/ottoman:release sh -c 'test ! -e /etc/sudoers.d/50-ottoman-dev && test ! -e /etc/containers/registries.conf.d/50-ottoman-dev.conf && cat /usr/share/ottoman/build-info' || { echo "release: dev files present in a release image" >&2; exit 1; }
echo "== 2. push $REG:stable and $REG:$TAG"
podman tag localhost/ottoman:release "$REG:stable" "$REG:$TAG"
podman push -q "$REG:$TAG" && podman push -q "$REG:stable"
DIGEST=$(skopeo inspect --format '{{.Digest}}' "docker://$REG:$TAG")
echo "pushed digest $DIGEST"
echo "== 3. netinstall ISO"
mkdir -p build/release
ISO="build/release/ottoman-$TAG-netinstall.iso"
IMAGE_REF="$REG:stable" ./scripts/make-netinst-iso.sh "$ISO" | tail -1
SUM=$(sha256sum "$ISO" | cut -c1-16); sha256sum "$ISO" > "$ISO.sha256"
OFF=""
if [ "${OFFLINE:-0}" = 1 ]; then
  echo "== 4. offline ISO (bib as root via the make-disk sudo rule)"
  sudo -n IMAGE_REF="$REG:stable" TYPE=anaconda-iso CONFIG= "$(pwd)/scripts/make-disk.sh" localhost/ottoman:release "$(pwd)/build/release" | tail -2
  OFFISO="build/release/ottoman-$TAG-offline.iso"; mv build/release/bootiso/install.iso "$OFFISO"; rmdir build/release/bootiso 2>/dev/null || true
  OFF=" offline $(basename "$OFFISO") $(sha256sum "$OFFISO" | cut -c1-16)"
fi
echo "== 5. record"
printf '| %s | %s | %s | %s | %s |%s\n' "$(date -u +%Y-%m-%dT%H:%MZ)" "$TAG" "${DIGEST:7:12}" "$(basename "$ISO")" "$SUM" "${OFF:+ $OFF}" >> docs/RELEASES.md
git add docs/RELEASES.md && git commit -qm "Release $TAG: $REG:stable = ${DIGEST:7:12}, $(basename "$ISO") sha256 $SUM...

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>" && git push -q
echo "release $TAG done: $REG:stable @ ${DIGEST:7:12}; ISO $ISO ($(stat -c %s "$ISO") bytes)${OFF}"

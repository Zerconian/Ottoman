#!/bin/bash
# Release path (zerc 2026-11-03: Gitea container registry, script now, CI runner later):
#   1. DEV=0 image (no dev user rule, no insecure dev registry) tagged :stable and :<date>-<sha> (immutable)
#   2. push both to <private-gitea>/zerc/ottoman (needs a prior `podman login <private-gitea>`)
#   3. clean installer ISO referencing :stable, no customizations, branded (brand-iso.sh) -> build/release/
#   4. a line in docs/RELEASES.md with digest + ISO sha256
# Refuses a dirty tree or an unpushed main. Prints pwd/branch/head first (gate rule). ~10 min on <build-host>.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "pwd: $(pwd)  branch: $(git rev-parse --abbrev-ref HEAD)  head: $(git rev-parse --short HEAD)"
REG=${REG:-<private-gitea>/zerc/ottoman}
git diff --quiet && git diff --cached --quiet || { echo "release: working tree is dirty; commit first" >&2; exit 2; }
git fetch -q origin && [ -z "$(git log origin/main..HEAD --oneline)" ] || { echo "release: unpushed commits on main; push first" >&2; exit 2; }
SHA=$(git rev-parse --short HEAD); TAG=$(date -u +%Y%m%d)-$SHA
podman login --get-login "${REG%%/*}" >/dev/null 2>&1 || { echo "release: not logged in: podman login ${REG%%/*} -u zerc (token with write:package)" >&2; exit 2; }
echo "== 1. build DEV=0 image"
DEV=0 ./scripts/build-image.sh localhost/ottoman:release | tail -1
podman run --rm localhost/ottoman:release sh -c 'test ! -e /etc/sudoers.d/50-ottoman-dev && test ! -e /etc/containers/registries.conf.d/50-ottoman-dev.conf && cat /usr/share/ottoman/build-info' || { echo "release: dev files present in a release image" >&2; exit 1; }
echo "== 2. push $REG:stable and $REG:$TAG"
podman tag localhost/ottoman:release "$REG:stable" "$REG:$TAG"
podman push -q "$REG:$TAG" && podman push -q "$REG:stable"
DIGEST=$(skopeo inspect --format '{{.Digest}}' "docker://$REG:$TAG")
echo "pushed digest $DIGEST"
echo "== 3. clean branded ISO (bib as root via the make-disk sudo rule)"
mkdir -p build/release
sudo -n IMAGE_REF="$REG:stable" TYPE=anaconda-iso CONFIG= "$(pwd)/scripts/make-disk.sh" localhost/ottoman:release "$(pwd)/build/release" | tail -3
ISO="build/release/ottoman-$TAG.iso"; mv build/release/bootiso/install.iso "$ISO"; rmdir build/release/bootiso 2>/dev/null || true
python3 -c "import json; m=json.load(open('build/release/manifest-anaconda-iso.json')); print('ISO installs from:', [c for p in m['pipelines'] for st in p.get('stages',[]) if st['type']=='org.osbuild.kickstart' for c in st['options']['%post'][0]['commands'] if 'bootc switch' in c][0])"
SUM=$(sha256sum "$ISO" | cut -c1-16)
echo "== 4. record"
printf '| %s | %s | %s | %s | %s |\n' "$(date -u +%Y-%m-%dT%H:%MZ)" "$TAG" "${DIGEST:7:12}" "$(basename "$ISO")" "$SUM" >> docs/RELEASES.md
git add docs/RELEASES.md && git commit -qm "Release $TAG: $REG:stable = ${DIGEST:7:12}, $(basename "$ISO") sha256 $SUM...

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>" && git push -q
echo "release $TAG done: $REG:stable @ ${DIGEST:7:12}; ISO $ISO ($(stat -c %s "$ISO") bytes)"

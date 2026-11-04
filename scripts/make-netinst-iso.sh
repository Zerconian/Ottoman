#!/bin/bash
# Build the public Ottoman installer: the stock Fedora netinstall ISO + our kickstart + branding. The OS image is
# pulled from the registry during the install (IMAGE_REF), so the ISO stays ~1.2 GB (fits a GitHub release asset);
# the offline ISO that embeds the image (make-disk.sh TYPE=anaconda-iso) is 2.8 GiB and stays a local build.
# No root, no mounts (xorriso + mtools, like brand-iso.sh). Usage:
#   IMAGE_REF=ghcr.io/<owner>/ottoman:stable scripts/make-netinst-iso.sh [out.iso]
# Env: NETINST_ISO (path to the Fedora netinstall; downloaded to ~/.cache/ottoman/ and checksum-verified if unset),
#      TIMEOUT (menu seconds, 5), TEST_USER + TEST_SSH_KEY (test builds only: a login user with passwordless sudo),
#      INSECURE_REGISTRY (test builds only: lets the installer pull from a plain-http dev registry).
set -euo pipefail
cd "$(dirname "$0")/.."
: "${IMAGE_REF:?IMAGE_REF=registry/owner/ottoman:tag is required}"
OUT=${1:-build/ottoman-netinstall.iso}; TIMEOUT=${TIMEOUT:-5}
FEDORA=44; REL=44-1.7; MIRROR=https://download.fedoraproject.org/pub/fedora/linux/releases/$FEDORA/Everything/x86_64/iso
NAME=Fedora-Everything-netinst-x86_64-$REL.iso
if [ -z "${NETINST_ISO:-}" ]; then
  mkdir -p ~/.cache/ottoman; NETINST_ISO=~/.cache/ottoman/$NAME
  if [ ! -f "$NETINST_ISO" ]; then
    echo "netinst: downloading $NAME (1.2 GB)"; curl -fsSL -o "$NETINST_ISO.part" "$MIRROR/$NAME"; mv "$NETINST_ISO.part" "$NETINST_ISO"
  fi
  [ -f ~/.cache/ottoman/Fedora-Everything-$REL-x86_64-CHECKSUM ] || curl -fsSL -o ~/.cache/ottoman/Fedora-Everything-$REL-x86_64-CHECKSUM "$MIRROR/Fedora-Everything-$REL-x86_64-CHECKSUM"
  ( cd ~/.cache/ottoman && sha256sum -c --ignore-missing --quiet Fedora-Everything-$REL-x86_64-CHECKSUM 2>/dev/null | grep -q "$NAME: OK" ) \
    || ( cd ~/.cache/ottoman && sha256sum -c --ignore-missing Fedora-Everything-$REL-x86_64-CHECKSUM 2>&1 | grep "$NAME" | grep -q ": OK" ) \
    || { echo "netinst: checksum mismatch for $NETINST_ISO" >&2; exit 1; }
fi
VOLID=$(xorriso -indev "$NETINST_ISO" -pvd_info 2>/dev/null | sed -n 's/^Volume Id *: *//p')
[ -n "$VOLID" ] || { echo "netinst: no volume id in $NETINST_ISO" >&2; exit 1; }
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
EFI_GUID=28732ac11ff8d211ba4b00a0c93ec93b
# ---- kickstart
sed "s|@IMAGE_REF@|$IMAGE_REF|g" image/installer/ottoman.ks > "$W/ottoman.ks"
grep -q "ostreecontainer --url=$IMAGE_REF " "$W/ottoman.ks" || { echo "netinst: kickstart substitution failed" >&2; exit 1; }
if [ -n "${TEST_USER:-}" ]; then
  printf 'user --name=%s --groups=wheel\nsshkey --username=%s "%s"\n%%post\nprintf "%s ALL=(ALL) NOPASSWD: ALL\\n" > /etc/sudoers.d/50-ottoman-test\n%%end\n' "$TEST_USER" "$TEST_USER" "${TEST_SSH_KEY:?TEST_SSH_KEY}" "$TEST_USER" >> "$W/ottoman.ks"
  echo "netinst: TEST build with login user $TEST_USER (never ship this ISO)"
fi
# ---- the three grub menus: ISO tree (EFI + BIOS) and the one inside the EFI System Partition that firmware boots
IV=$(xorriso -indev "$NETINST_ISO" -report_el_torito as_mkisofs 2>/dev/null | sed -n 's/.*--interval:local_fs:\([0-9]*\)d-\([0-9]*\)d.*/\1 \2/p')
[ -n "$IV" ] || { echo "netinst: no appended EFI partition interval found" >&2; exit 1; }
set -- $IV; dd if="$NETINST_ISO" of="$W/efiboot.img" bs=512 skip="$1" count=$(( $2 - $1 + 1 )) status=none
xorriso -osirrox on -indev "$NETINST_ISO" -extract /EFI/BOOT/grub.cfg "$W/efi-tree-grub.cfg" -extract /boot/grub2/grub.cfg "$W/bios-grub.cfg" >/dev/null 2>&1
chmod u+w "$W"/*; mcopy -i "$W/efiboot.img" ::/EFI/BOOT/grub.cfg "$W/efi-img-grub.cfg"
edit_grub() {
  # default entry 1 on the stock ISO is the media check, which fails on a rewritten ISO (its implanted md5 is stale):
  # boot straight into the install (entry 0), the media-check entry stays in the menu for the curious.
  sed -i -e "s/^set timeout=60$/set timeout=$TIMEOUT/" -e 's/^set default="1"$/set default="0"/' \
    -e "s/'Install Fedora $FEDORA'/'Install Ottoman'/" -e "s/'Test this media & install Fedora $FEDORA'/'Test this media \& install Ottoman'/" \
    -e "s/'Install Fedora $FEDORA in basic graphics mode'/'Install Ottoman in basic graphics mode'/" -e "s/'Rescue a Fedora system'/'Rescue an Ottoman system'/" \
    -e "/^\s*linux .*inst\.rescue/!s|^\(\s*linux .*\) quiet$|\1 inst.ks=hd:LABEL=$VOLID:/ottoman.ks quiet rhgb|" "$1"
  # Branded boot screen (zerc 2026-11-04): gfxmenu theme (built into the signed EFI grub; gfxterm_background is not, so
  # background_image cannot work there) with the Ottoman background, and the "Booting ..." line in dark grey. After the search line (paths need $root).
  sed -i "/^search --no-floppy --set=root/a\\
insmod gfxterm\\
insmod png\\
if loadfont /EFI/BOOT/fonts/unicode.pf2; then insmod gfxmenu; terminal_output gfxterm; set theme=/ottoman-theme/theme.txt; export theme; fi\\
set color_normal=dark-gray/black\\
set menu_color_normal=light-gray/black\\
set menu_color_highlight=black/light-gray" "$1"
  grep -q "^set timeout=$TIMEOUT$" "$1" && grep -q '^set default="0"$' "$1" && [ "$(grep -c "inst.ks=hd:LABEL=$VOLID:/ottoman.ks quiet rhgb$" "$1")" -eq 3 ] && ! grep -q "Fedora $FEDORA'" "$1" && grep -q "set theme=/ottoman-theme/theme.txt" "$1" \
    || { echo "netinst: grub edit failed in $1" >&2; exit 1; }
}
for f in efi-tree-grub.cfg bios-grub.cfg efi-img-grub.cfg; do edit_grub "$W/$f"; done
mcopy -o -i "$W/efiboot.img" "$W/efi-img-grub.cfg" ::/EFI/BOOT/grub.cfg
# ---- product.img: anaconda overlay (sidebar artwork; test builds may add an insecure-registry entry for the installer)
rm -rf "$W/overlay"; cp -r image/installer/overlay "$W/overlay"
if [ -n "${INSECURE_REGISTRY:-}" ]; then mkdir -p "$W/overlay/etc/containers/registries.conf.d"; printf '[[registry]]\nlocation = "%s"\ninsecure = true\n' "$INSECURE_REGISTRY" > "$W/overlay/etc/containers/registries.conf.d/50-ottoman-test.conf"; echo "netinst: TEST build pulls from insecure $INSECURE_REGISTRY"; fi
( cd "$W/overlay" && find . -type f | sed 's|^\./||' | cpio -o -H newc --quiet | gzip -9 ) > "$W/product.img"
[ "$(zcat "$W/product.img" | cpio -t --quiet | wc -l)" -ge 2 ] || { echo "netinst: product.img is empty" >&2; exit 1; }
# ---- write the ISO: replay the original boot setup, swap in the edited EFI partition, add the kickstart and overlay
mkdir -p "$(dirname "$OUT")"; rm -f "$OUT"   # xorriso refuses to overwrite an existing image
xorriso -indev "$NETINST_ISO" -outdev "$OUT" -boot_image any replay \
  -append_partition 2 "$EFI_GUID" "$W/efiboot.img" -boot_image any efi_path=--interval:appended_partition_2:all:: \
  -map "$W/efi-tree-grub.cfg" /EFI/BOOT/grub.cfg -map "$W/bios-grub.cfg" /boot/grub2/grub.cfg \
  -map "$W/ottoman.ks" /ottoman.ks -map "$W/product.img" /images/product.img -map image/installer/grub/theme.txt /ottoman-theme/theme.txt -map image/installer/grub/background.png /ottoman-theme/background.png >"$W/xorriso.log" 2>&1 \
  || { echo "netinst: xorriso failed:"; tail -5 "$W/xorriso.log"; exit 1; }
# ---- proof on the result
xorriso -indev "$OUT" -report_el_torito plain 2>/dev/null | grep -q "UEFI" || { echo "netinst: no UEFI boot image in the result" >&2; exit 1; }
xorriso -indev "$OUT" -report_el_torito plain 2>/dev/null | grep -q "BIOS" || { echo "netinst: no BIOS boot image in the result" >&2; exit 1; }
IV2=$(xorriso -indev "$OUT" -report_el_torito as_mkisofs 2>/dev/null | sed -n 's/.*-append_partition 2 [0-9a-f]* --interval:local_fs:\([0-9]*\)d-\([0-9]*\)d.*/\1 \2/p')
[ -n "$IV2" ] || { echo "netinst: result has no appended EFI partition" >&2; exit 1; }
set -- $IV2; dd if="$OUT" of="$W/check-efiboot.img" bs=512 skip="$1" count=$(( $2 - $1 + 1 )) status=none
mcopy -i "$W/check-efiboot.img" ::/EFI/BOOT/grub.cfg "$W/check-grub.cfg"; grep -q "^set timeout=$TIMEOUT$" "$W/check-grub.cfg" || { echo "netinst: EFI partition in the result still has the old menu" >&2; exit 1; }
xorriso -osirrox on -indev "$OUT" -extract /ottoman.ks "$W/check.ks" >/dev/null 2>&1; grep -q "ostreecontainer --url=$IMAGE_REF " "$W/check.ks" || { echo "netinst: kickstart missing from the result" >&2; exit 1; }
echo "netinst: $OUT ($(stat -c %s "$OUT") bytes) installs $IMAGE_REF; menu $TIMEOUT s; volid $VOLID; sha256 $(sha256sum "$OUT" | cut -c1-16)"

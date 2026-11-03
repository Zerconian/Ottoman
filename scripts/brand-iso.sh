#!/bin/bash
# Post-process bootc-image-builder's anaconda ISO (zerc 2026-11-03: hide the installer junk):
#   - boot menu countdown 60 s -> $TIMEOUT s (both grub.cfg copies in the ISO tree and the one inside the EFI boot image)
#   - 'rhgb' on the installer kernel lines so Plymouth covers the installer's own boot
#   - images/product.img: anaconda's stock overlay hook (anaconda-lib.sh anaconda_auto_updates), a gzip cpio of
#     image/installer/overlay/ -> Ottoman sidebar artwork instead of Fedora's
# No root, no mounts: mtools edits the FAT EFI image, xorriso rewrites the ISO keeping the BIOS El Torito image,
# the GRUB MBR and the GPT, and swaps the appended EFI partition for the edited image. Usage: brand-iso.sh [iso]
set -euo pipefail
cd "$(dirname "$0")/.."
ISO=${1:-build/disk/bootiso/install.iso}; TIMEOUT=${TIMEOUT:-5}
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
EFI_GUID=28732ac11ff8d211ba4b00a0c93ec93b   # EFI System Partition type, as xorriso reports it
edit_grub() {  # $1 file: countdown, rhgb, grammar; every edit asserted
  sed -i -e "s/^set timeout=60$/set timeout=$TIMEOUT/" -e '/^\s*linux /s/ quiet$/ quiet rhgb/' -e 's/a Ottoman system/an Ottoman system/' "$1"
  grep -q "^set timeout=$TIMEOUT$" "$1" && [ "$(grep -c 'quiet rhgb$' "$1")" -ge 2 ] || { echo "brand-iso: grub edit failed in $1" >&2; exit 1; }
}
xorriso -osirrox on -indev "$ISO" -extract /EFI/BOOT/grub.cfg "$W/efi-tree-grub.cfg" -extract /boot/grub2/grub.cfg "$W/bios-grub.cfg" -extract /images/efiboot.img "$W/efiboot.img" >/dev/null 2>&1
chmod u+w "$W"/*
mcopy -i "$W/efiboot.img" ::/EFI/BOOT/grub.cfg "$W/efi-img-grub.cfg"
for f in efi-tree-grub.cfg bios-grub.cfg efi-img-grub.cfg; do edit_grub "$W/$f"; done
mcopy -o -i "$W/efiboot.img" "$W/efi-img-grub.cfg" ::/EFI/BOOT/grub.cfg
( cd image/installer/overlay && find usr -type f | cpio -o -H newc --quiet | gzip -9 ) > "$W/product.img"
[ "$(zcat "$W/product.img" | cpio -t --quiet | wc -l)" -ge 2 ] || { echo "brand-iso: product.img is empty" >&2; exit 1; }
OUT="$ISO.branded"
xorriso -indev "$ISO" -outdev "$OUT" -boot_image any replay \
  -append_partition 2 "$EFI_GUID" "$W/efiboot.img" -boot_image any efi_path=--interval:appended_partition_2:all:: \
  -map "$W/efi-tree-grub.cfg" /EFI/BOOT/grub.cfg -map "$W/bios-grub.cfg" /boot/grub2/grub.cfg \
  -map "$W/efiboot.img" /images/efiboot.img -map "$W/product.img" /images/product.img >"$W/xorriso.log" 2>&1 \
  || { echo "brand-iso: xorriso failed:"; tail -5 "$W/xorriso.log"; exit 1; }
# proof on the result: both boot images present, EFI image is the edited one, product.img in place
xorriso -indev "$OUT" -report_el_torito plain 2>/dev/null | grep -q "UEFI" || { echo "brand-iso: no UEFI boot image in the result" >&2; exit 1; }
xorriso -osirrox on -indev "$OUT" -extract /images/efiboot.img "$W/check-efiboot.img" -extract /images/product.img "$W/check-product.img" >/dev/null 2>&1
chmod u+w "$W"/check-*; mcopy -i "$W/check-efiboot.img" ::/EFI/BOOT/grub.cfg "$W/check-grub.cfg"
grep -q "^set timeout=$TIMEOUT$" "$W/check-grub.cfg" || { echo "brand-iso: EFI image in the result still has the old menu" >&2; exit 1; }
# the appended EFI partition must be the edited image too (that is what UEFI firmware boots)
xorriso -indev "$OUT" -report_el_torito as_mkisofs 2>/dev/null | grep -q "append_partition 2" || { echo "brand-iso: no appended EFI partition" >&2; exit 1; }
mv "$OUT" "$ISO"
echo "brand-iso: $ISO rewritten: menu timeout $TIMEOUT s, rhgb, product.img ($(stat -c %s "$W/product.img") bytes, $(zcat "$W/product.img" | cpio -t --quiet | tr '\n' ' '))"

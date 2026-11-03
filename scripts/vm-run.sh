#!/bin/bash
# Boot the qcow2 from make-disk.sh in QEMU with a virtio-gpu display and a serial console in the
# terminal. Needs qemu-system-x86-core + edk2-ovmf (sudo dnf install qemu-system-x86-core qemu-img edk2-ovmf).
# No hardware video decode in a VM: this proves boot, session start and the launcher, nothing about codecs.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "pwd: $(pwd)  branch: $(git rev-parse --abbrev-ref HEAD)  head: $(git rev-parse --short HEAD)"
DISK=${1:-$(ls -t build/disk/qcow2/*.qcow2 2>/dev/null | head -1)}
[ -f "$DISK" ] || { echo "no qcow2 found; run make-disk.sh first" >&2; exit 2; }
OVMF=/usr/share/edk2/ovmf/OVMF_CODE.fd
[ -f "$OVMF" ] || { echo "missing $OVMF (dnf install edk2-ovmf)" >&2; exit 2; }
MEM=${MEM:-4096}
exec qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m "$MEM" \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF" \
  -drive file="$DISK",if=virtio,format=qcow2 \
  -device virtio-gpu-gl -display gtk,gl=on \
  -device virtio-keyboard -device virtio-tablet \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
  -audiodev pipewire,id=a0 -device intel-hda -device hda-output,audiodev=a0 \
  -serial mon:stdio

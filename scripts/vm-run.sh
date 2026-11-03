#!/bin/bash
# Boot the qcow2 from make-disk.sh in QEMU. The base disk is never written: each run boots a fresh
# copy-on-write overlay (pass KEEP=1 to reuse the last overlay and keep its state).
# Needs qemu-system-x86-core, qemu-img, edk2-ovmf. No hardware video decode in a VM: this proves boot,
# the session service and the launcher, nothing about codecs.
#   ./scripts/vm-run.sh                 GUI window (gtk), serial + monitor on this terminal
#   HEADLESS=1 ./scripts/vm-run.sh      detached: VNC 127.0.0.1:18820, serial -> log, monitor -> unix socket
set -euo pipefail
cd "$(dirname "$0")/.."
echo "pwd: $(pwd)  branch: $(git rev-parse --abbrev-ref HEAD)  head: $(git rev-parse --short HEAD)"
DISK=${1:-$(ls -t build/disk/qcow2/*.qcow2 2>/dev/null | head -1)}
[ -f "$DISK" ] || { echo "no qcow2 found; run make-disk.sh first" >&2; exit 2; }
OVMF=/usr/share/edk2/ovmf/OVMF_CODE.fd
[ -f "$OVMF" ] || { echo "missing $OVMF (dnf install edk2-ovmf)" >&2; exit 2; }
[ -w /dev/kvm ] || { echo "/dev/kvm not writable by $(id -un)" >&2; exit 2; }
MEM=${MEM:-4096}
VMDIR=${VMDIR:-$HOME/.local/share/claude-scratch/ottoman/vm}
mkdir -p "$VMDIR"
OVERLAY=$VMDIR/overlay.qcow2
if [ "${KEEP:-0}" != 1 ] || [ ! -f "$OVERLAY" ]; then
  rm -f "$OVERLAY"
  qemu-img create -q -f qcow2 -b "$(realpath "$DISK")" -F qcow2 "$OVERLAY"
  echo "fresh overlay on $(realpath "$DISK")"
fi
COMMON=(-accel kvm -cpu host -smp 4 -m "$MEM"
  -drive if=pflash,format=raw,readonly=on,file="$OVMF"
  -drive file="$OVERLAY",if=virtio,format=qcow2
  -device virtio-keyboard -device virtio-tablet
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:18822-:22 -device virtio-net-pci,netdev=n0)   # ssh: scripts/vm-ssh.sh
# Display device: qemu-system-x86-core splits display devices into modules; probe what this host has.
pick_gpu() { for d in virtio-vga virtio-gpu-pci bochs-display; do qemu-system-x86_64 -device "$d,help" >/dev/null 2>&1 && { echo "$d"; return; }; done; echo VGA; }
GPU=${GPU:-$(pick_gpu)}
echo "display device: $GPU"
if [ "${HEADLESS:-0}" = 1 ]; then
  : > "$VMDIR/serial.log"
  rm -f "$VMDIR/mon.sock"
  setsid qemu-system-x86_64 "${COMMON[@]}" \
    -device "$GPU" -display none -vnc 127.0.0.1:12920 \
    -monitor unix:"$VMDIR/mon.sock",server,nowait \
    -serial file:"$VMDIR/serial.log" \
    -pidfile "$VMDIR/qemu.pid" >"$VMDIR/qemu.out" 2>&1 < /dev/null &
  sleep 2
  echo "qemu pid $(cat "$VMDIR/qemu.pid" 2>/dev/null || echo '?'), VNC 127.0.0.1:18820, ssh 127.0.0.1:18822, serial $VMDIR/serial.log, monitor $VMDIR/mon.sock"
else
  # qemu-system-x86-core ships no window backend; gtk/sdl come from qemu-ui-gtk / qemu-ui-sdl.
  UI=""; for d in gtk sdl; do qemu-system-x86_64 -display help 2>/dev/null | command grep -qx "$d" && { UI=$d; break; }; done
  [ -n "$UI" ] || { echo "no window backend: sudo dnf install qemu-ui-gtk   (or use HEADLESS=1 and a VNC viewer on 127.0.0.1:18820)" >&2; exit 2; }
  exec qemu-system-x86_64 "${COMMON[@]}" \
    -device "$GPU" -display "$UI" \
    -audiodev pipewire,id=a0 -device intel-hda -device hda-output,audiodev=a0 \
    -serial mon:stdio
fi

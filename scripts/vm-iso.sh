#!/bin/bash
# Boot the installer ISO in QEMU against a blank disk (default 24 GB), headless: VNC 127.0.0.1:18820, ssh forward
# :18822 and phone-remote forward :18824 for after the install. State lives in a separate dir so the dev VM is untouched.
set -euo pipefail
cd "$(dirname "$0")/.."
ISO=${1:-build/disk/bootiso/install.iso}
[ -f "$ISO" ] || { echo "no ISO at $ISO (sudo TYPE=anaconda-iso scripts/make-disk.sh)" >&2; exit 2; }
OVMF=/usr/share/edk2/ovmf/OVMF_CODE.fd
VMDIR=${VMDIR:-$HOME/.local/share/claude-scratch/ottoman/vm-iso}
DISK=$VMDIR/disk.qcow2; SIZE=${SIZE:-24G}; MEM=${MEM:-6144}
mkdir -p "$VMDIR"
[ -f "$DISK" ] && [ "${KEEP:-0}" = 1 ] || qemu-img create -q -f qcow2 "$DISK" "$SIZE"
# OVMF vars copy so the firmware can keep boot entries the installer writes
[ -f "$VMDIR/OVMF_VARS.fd" ] || cp /usr/share/edk2/ovmf/OVMF_VARS.fd "$VMDIR/OVMF_VARS.fd"
GPU=${GPU:-virtio-vga}; qemu-system-x86_64 -device "$GPU,help" >/dev/null 2>&1 || GPU=bochs-display   # GPU=bochs-display: plain framebuffer, no virtio damage transfers
: > "$VMDIR/serial.log"; rm -f "$VMDIR/mon.sock"
BOOT=(-cdrom "$ISO" -boot order=d); [ "${KEEP:-0}" = 1 ] && [ "${NOCD:-0}" = 1 ] && BOOT=()
# AUDIO=N: N emulated Intel HDA output codecs on a silent backend, so PipeWire gets real sinks and Settings > Audio has
# something to list and switch (the headless VM otherwise has no sound card at all; measured 2026-11-05). 2 proves a switch.
# LAN=1: expose the phone-facing ports on every host address (the browser remote on :18824, the Android TV Remote server
# on 6466/6467) so a real phone on the LAN can reach the VM's shell. User-mode networking cannot carry mDNS to the LAN,
# so pair this with scripts/vm-lan-publish.sh, which announces the service from the host's avahi (measured 2026-11-05).
BIND=127.0.0.1; LANFWD=; if [ "${LAN:-0}" = 1 ]; then BIND=0.0.0.0; LANFWD=",hostfwd=tcp:0.0.0.0:6466-:6466,hostfwd=tcp:0.0.0.0:6467-:6467"; fi
SND=(); if [ "${AUDIO:-0}" -gt 0 ]; then SND=(-audiodev none,id=a0); for i in $(seq 1 "$AUDIO"); do SND+=(-device "intel-hda,id=hda$i" -device "hda-output,bus=hda$i.0,audiodev=a0"); done; fi
setsid qemu-system-x86_64 -accel kvm -cpu host -smp 4 -m "$MEM" \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF" \
  -drive if=pflash,format=raw,file="$VMDIR/OVMF_VARS.fd" \
  -drive file="$DISK",if=virtio,format=qcow2 "${BOOT[@]}" \
  -device "$GPU" -display none -vnc 127.0.0.1:12920 \
  -device virtio-keyboard -device virtio-tablet "${SND[@]}" \
  -netdev "user,id=n0,hostfwd=tcp:127.0.0.1:18822-:22,hostfwd=tcp:$BIND:18824-:18820$LANFWD" -device virtio-net-pci,netdev=n0 \
  -monitor unix:"$VMDIR/mon.sock",server,nowait -serial file:"$VMDIR/serial.log" -pidfile "$VMDIR/qemu.pid" >"$VMDIR/qemu.out" 2>&1 < /dev/null &
sleep 2
echo "installer VM pid $(cat "$VMDIR/qemu.pid" 2>/dev/null || echo '?'): VNC 127.0.0.1:18820, disk $DISK ($SIZE), monitor $VMDIR/mon.sock"
echo "after installing: KEEP=1 NOCD=1 scripts/vm-iso.sh boots the installed disk (AUDIO=N adds N HDA sound cards, LAN=1 exposes the phone ports on the LAN)"

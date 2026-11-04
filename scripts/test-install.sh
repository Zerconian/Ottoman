#!/bin/bash
# M6 dress rehearsal: boot the installer ISO against a blank disk, record the whole thing as screendumps every
# 2 s (installer boot, anaconda, reboot, first run), drive first run from the QEMU monitor (Language > Network >
# Setup), then prove the result over ssh. Prints wall time; cap ~25 min. Frames: $VMDIR/frames/NNN.png.
# Needs: build/disk/bootiso/install.iso (sudo TYPE=anaconda-iso scripts/make-disk.sh), VNC/ssh ports 18820/18822 free.
set -uo pipefail
cd "$(dirname "$0")/.."
echo "pwd: $(pwd)  branch: $(git rev-parse --abbrev-ref HEAD)  head: $(git rev-parse --short HEAD)"
export VMDIR=${VMDIR:-$HOME/.local/share/claude-scratch/ottoman/vm-iso}
ISO=${ISO:-build/disk/bootiso/install.iso}
. ./scripts/dev-env.sh
SSH="ssh -i $DEV_SSH_IDENTITY -p 18822 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=3 $DEV_USER@127.0.0.1"
T0=$(date +%s); F=$VMDIR/frames; rm -rf "$F"; mkdir -p "$F"; n=0
frame() { printf 'screendump %s/%03d.ppm\n' "$F" "$n" | socat - UNIX-CONNECT:"$VMDIR/mon.sock" >/dev/null 2>&1; n=$((n+1)); }
key() { ./scripts/vm-type.sh "" "$@"; }
elapsed() { echo "[$(( $(date +%s) - T0 )) s] $*"; }
# ---- 1. installer boot + unattended install, frames every 2 s until the %post marker hits the serial log
./scripts/vm-iso.sh "$ISO" | head -1
INSTALL_START=$(date +%s)
while ! command grep -q "Install finished" "$VMDIR/serial.log" 2>/dev/null; do
  frame; sleep 2
  [ $(( $(date +%s) - INSTALL_START )) -gt 1200 ] && { elapsed "FAIL: no 'Install finished' on serial after 20 min (last frame $((n-1)))"; exit 1; }
done
elapsed "install finished (frames 000-$((n-1)))"
# ---- 2. reboot into the installed disk: keep framing until ssh answers (first boot = first run)
while ! $SSH true 2>/dev/null; do frame; sleep 2; [ $(( $(date +%s) - T0 )) -gt 1500 ] && { elapsed "FAIL: no ssh after reboot"; exit 1; }; done
elapsed "installed system up, ssh ok (frame $((n-1)))"
sleep 4; frame
# ---- 3. first run: Language (English US preselected) > Network (wired, Continue) > Setup (installs defaults) > launcher
ui() { $SSH "sudo -n journalctl -b --no-pager -o cat _COMM=ottoman-shell 2>/dev/null | command grep -E 'ui:|firstrun|setup|system:' | tail -${1:-4}"; }
echo "--- shell state before any key:"; ui 6
key ret; sleep 2; frame; echo "--- after Enter on Language:"; ui 3
sleep 3; frame; key ret; sleep 2; frame; echo "--- after Enter on Network:"; ui 3
SETUP_START=$(date +%s)
while ! $SSH "sudo -n journalctl -b --no-pager -o cat _COMM=ottoman-shell 2>/dev/null | command grep -q -E 'first run done|firstrun setup done'"; do
  frame; sleep 10
  [ $(( $(date +%s) - SETUP_START )) -gt 900 ] && { elapsed "setup not done after 15 min; last ui lines:"; ui 8; break; }
done
sleep 3; frame; elapsed "setup phase over (frame $((n-1)))"; ui 6
# ---- 4. proofs over ssh
echo "--- proofs:"
$SSH 'echo "sudo -n: $(sudo -n true 2>&1 && echo ok)"; echo "registry conf: $(grep -c insecure /etc/containers/registries.conf.d/50-ottoman-dev.conf 2>/dev/null) entries"; sudo -n bootc status --format json | python3 -c "import sys,json; d=json.load(sys.stdin)[\"status\"][\"booted\"][\"image\"]; print(\"image ref:\", d[\"image\"][\"image\"], \"transport\", d[\"image\"][\"transport\"], \"digest\", d[\"imageDigest\"][7:19])"; echo "greenboot grub snippet: $(sudo -n grep -c boot_counter /boot/grub2/grub.cfg 2>/dev/null) lines"; echo "grub timeout: $(sudo -n grep -h -E "^set timeout" /boot/grub2/grub.cfg 2>/dev/null | tr "\n" " ")"; echo "pretty: $(grep PRETTY /etc/os-release)"; systemctl is-active greenboot-success.target ottoman-session.service | tr "\n" " "; echo; systemd-analyze | head -1; echo "first-run done flag: $(sudo -n ls /var/home/ottoman/.config/ottoman/ 2>/dev/null | tr "\n" " ")"; echo "apps installed: $(sudo -n -u ottoman flatpak --user list --app --columns=application 2>/dev/null | tr "\n" " ")"'
for f in "$F"/*.ppm; do magick "$f" "${f%.ppm}.png" 2>/dev/null && rm -f "$f"; done
elapsed "done: $n frames in $F"

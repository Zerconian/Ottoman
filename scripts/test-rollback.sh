#!/bin/bash
# M5 proof: push a broken image under the dev tag, upgrade the VM to it, and watch greenboot + grub roll back.
# Restores the good image under the dev tag afterwards. Prints bootc's booted digest before and after.
set -uo pipefail
cd "$(dirname "$0")/.."
SSH=./scripts/vm-ssh.sh
GOOD=$(podman image inspect localhost/ottoman:good --format '{{.Id}}' | cut -c1-12)
echo "good image $GOOD"
podman build -q -t localhost/ottoman:broken -f image/Containerfile.broken . >/dev/null || { echo "broken build failed"; exit 1; }
podman tag localhost/ottoman:broken localhost:18821/ottoman:dev && podman push -q --tls-verify=false localhost:18821/ottoman:dev
echo "broken image pushed as dev: $(podman image inspect localhost/ottoman:broken --format '{{.Id}}' | cut -c1-12)"
$SSH 'sudo bootc status --format json | python3 -c "import sys,json; d=json.load(sys.stdin)[\"status\"]; print(\"booted before:\", d[\"booted\"][\"image\"][\"imageDigest\"][7:19])"'
$SSH 'sudo bootc upgrade 2>&1 | tail -1; sudo bootc status --format json | python3 -c "import sys,json; d=json.load(sys.stdin)[\"status\"]; print(\"staged:\", (d.get(\"staged\") or {}).get(\"image\",{}).get(\"imageDigest\",\"-\")[7:19])"; sudo grub2-editenv - list; sudo systemctl reboot' 2>/dev/null
echo "rebooting into the broken image at $(date +%T); greenboot allows 3 attempts, each up to ~2 min"
sleep 60; n=60; ok=0
until [ $n -ge 900 ]; do
  if $SSH -o ConnectTimeout=3 'systemctl is-active --quiet greenboot-success.target' 2>/dev/null; then ok=1; break; fi
  sleep 10; n=$((n+10)); printf '.'
done; echo
if [ $ok = 1 ]; then echo "healthy boot (greenboot-success.target) reached after ~${n}s"; else echo "NO healthy boot within ${n}s: rollback did not happen"; fi
$SSH 'sudo bootc status --format json | python3 -c "import sys,json; d=json.load(sys.stdin)[\"status\"]; print(\"booted after:\", d[\"booted\"][\"image\"][\"imageDigest\"][7:19]); print(\"rollback slot:\", (d.get(\"rollback\") or {}).get(\"image\",{}).get(\"imageDigest\",\"-\")[7:19])"; echo "== greenboot journal (all boots)"; sudo journalctl --no-pager -o short-monotonic -u greenboot-healthcheck 2>&1 | command grep -E "ottoman:|FAIL|fail|Boot Status|rollback|Succeeded|Failed" | tail -12; echo "== boots seen"; sudo journalctl --list-boots --no-pager | tail -5; sudo grub2-editenv - list'
# restore the good image under the dev tag
podman tag localhost/ottoman:good localhost:18821/ottoman:dev && podman push -q --tls-verify=false localhost:18821/ottoman:dev && echo "dev tag restored to the good image"

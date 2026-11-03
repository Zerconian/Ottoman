#!/bin/bash
# Dev loop: pull the latest ottoman:dev from the local registry into the running VM, reboot, wait for ssh.
# `bootc switch <same ref>` is a no-op ("Image specification is unchanged"); `bootc upgrade` re-pulls the tag.
set -uo pipefail
cd "$(dirname "$0")/.."
SSH=./scripts/vm-ssh.sh
WANT=$(curl -fsS http://127.0.0.1:18821/v2/ottoman/manifests/dev -H 'Accept: application/vnd.oci.image.manifest.v1+json' | python3 -c "import sys,json; print(json.load(sys.stdin)['config']['digest'][7:19])")
echo "registry dev config id: $WANT"
$SSH 'sudo bootc status --format json | python3 -c "import sys,json; d=json.load(sys.stdin)[\"status\"][\"booted\"][\"image\"]; print(\"booted now:\", d[\"image\"][\"image\"], d[\"imageDigest\"][7:19])"'
$SSH 'sudo bootc upgrade 2>&1 | tail -3; sudo systemctl reboot' 2>/dev/null
sleep 20; n=0
until $SSH -o ConnectTimeout=3 true 2>/dev/null || [ $n -ge 240 ]; do sleep 3; n=$((n+3)); done
echo "ssh back after ~${n}s"
$SSH 'sudo bootc status --format json | python3 -c "import sys,json; d=json.load(sys.stdin)[\"status\"][\"booted\"][\"image\"]; print(\"booted after:\", d[\"image\"][\"image\"], d[\"imageDigest\"][7:19])"; systemd-analyze | head -1'

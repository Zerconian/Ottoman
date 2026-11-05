#!/bin/bash
# Announce the test VM's Android TV Remote server on the LAN from the host's avahi, for a real-phone test of the VM.
# QEMU user-mode networking forwards TCP (scripts/vm-iso.sh LAN=1 binds 6466/6467 and 18824 on 0.0.0.0) but cannot
# carry the VM's own mDNS to the LAN, so the host advertises `_androidtvremote2._tcp` on its own address instead; the
# phone then pairs straight through the forward to the shell in the VM. Runs detached until scripts/vm-lan-publish.sh stop.
set -euo pipefail
VMDIR=${VMDIR:-$HOME/.local/share/claude-scratch/ottoman/vm-iso}; PIDF=$VMDIR/avahi-publish.pid
if [ "${1:-}" = stop ]; then [ -f "$PIDF" ] && kill "$(cat "$PIDF")" 2>/dev/null && echo "stopped $(cat "$PIDF")"; rm -f "$PIDF"; exit 0; fi
NAME=${NAME:-ottoman}; MAC=${MAC:-52:54:00:12:34:56}   # QEMU's default NIC MAC; the record only needs to be well-formed
[ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null && { echo "already publishing (pid $(cat "$PIDF"))"; exit 0; }
setsid avahi-publish -s "$NAME" _androidtvremote2._tcp 6466 "bt=$MAC" >"$VMDIR/avahi-publish.log" 2>&1 < /dev/null &
echo $! > "$PIDF"; sleep 1
echo "publishing $NAME._androidtvremote2._tcp on this host's addresses (pid $(cat "$PIDF")); check: avahi-browse -rt _androidtvremote2._tcp"

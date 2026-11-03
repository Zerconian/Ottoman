#!/bin/bash
# greenboot required check (M5): a boot is healthy only if the TV session is up: the session unit is active,
# sway answers on its IPC socket, and the launcher window exists. Up to 90 s of patience for slow boxes.
set -u
for i in $(seq 1 45); do
  if systemctl is-active --quiet ottoman-session.service; then
    S=$(ls /run/user/*/sway-ipc.*.sock 2>/dev/null | head -1)
    U=$(stat -c %U "$S" 2>/dev/null)
    if [ -n "$S" ] && runuser -u "$U" -- env SWAYSOCK="$S" swaymsg -t get_tree 2>/dev/null | grep -q '"app_id": "ottoman-shell"'; then
      echo "ottoman: session active, launcher window present"; exit 0
    fi
  fi
  sleep 2
done
echo "ottoman: launcher not up after 90 s (session $(systemctl is-active ottoman-session.service))" >&2
exit 1

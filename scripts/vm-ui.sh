#!/bin/bash
# Drive the shell one step at a time: send keys (QEMU key names) and print the shell's "ui:" journal lines
# that follow, so a test knows where focus is before the next key. Usage: vm-ui.sh key [key ...]
#   vm-ui.sh down down ret        vm-ui.sh --state   (just print the last few ui lines)
set -uo pipefail
cd "$(dirname "$0")/.."
SSH=./scripts/vm-ssh.sh
cursor=$($SSH 'sudo journalctl -b --no-pager -o short-monotonic _COMM=ottoman-shell 2>/dev/null | wc -l')
# --state: show the last few lines unconditionally (it used to show only lines newer than its own start, i.e. nothing).
if [ "${1:-}" = "--state" ]; then cursor=$((cursor - 8)); [ $cursor -lt 0 ] && cursor=0; else ./scripts/vm-type.sh "" "$@"; sleep "${UI_WAIT:-1.2}"; fi
$SSH "sudo journalctl -b --no-pager -o short-monotonic _COMM=ottoman-shell 2>/dev/null | tail -n +$((cursor + 1)) | command grep -E 'ui:|system:|jellyfin:' | sed -e 's/^.*ottoman-shell\[[0-9]*\]: //' | tail -8"

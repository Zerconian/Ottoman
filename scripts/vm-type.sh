#!/bin/bash
# Type a string into the headless VM through the QEMU monitor (sendkey). Usage: vm-type.sh "text" [key ...]
# Extra args are raw QEMU key names sent after the text (ret, down, tab, esc, home...).
set -euo pipefail
V=${VMDIR:-$HOME/.local/share/claude-scratch/ottoman/vm}   # PORT_BASE is not needed here: keys go through the monitor socket
key() { printf 'sendkey %s\n' "$1" | socat - UNIX-CONNECT:"$V/mon.sock" >/dev/null; sleep 0.06; }
s=${1:-}; shift || true
for ((i=0; i<${#s}; i++)); do
  c=${s:$i:1}
  case "$c" in
    [a-z0-9]) key "$c" ;;
    [A-Z]) key "shift-$(tr 'A-Z' 'a-z' <<<"$c")" ;;
    .) key dot ;; ,) key comma ;; -) key minus ;; _) key shift-minus ;; :) key shift-semicolon ;; /) key slash ;;
    ' ') key spc ;; @) key shift-2 ;; '!') key shift-1 ;; '=') key equal ;; '+') key shift-equal ;;
    *) echo "vm-type: no mapping for '$c'" >&2; exit 2 ;;
  esac
done
for k in "$@"; do key "$k"; sleep 0.2; done

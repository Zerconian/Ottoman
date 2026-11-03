#!/bin/bash
# saver.sh on|off: start the screensaver window (once) or kill it. Called by swayidle.
case "$1" in
  on)  swaymsg -t get_tree | grep -q '"app_id": "ottoman-saver"' && exit 0
       setsid /usr/libexec/ottoman/ottoman-shell --saver >/dev/null 2>&1 < /dev/null & ;;
  off) swaymsg '[app_id="ottoman-saver"] kill' >/dev/null ;;
esac

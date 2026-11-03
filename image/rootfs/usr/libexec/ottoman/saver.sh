#!/bin/bash
# saver.sh on|off: start the screensaver window (once) or kill it. Called by swayidle.
case "$1" in
  on)  swaymsg -t get_tree | grep -q '"app_id": "ottoman-saver"' && exit 0
       MODE=clock; [ -f "$HOME/.config/ottoman/saver.conf" ] && . "$HOME/.config/ottoman/saver.conf"   # MODE=clock|aurora|stars (Settings > Display)
       setsid /usr/libexec/ottoman/ottoman-shell --saver "--mode=$MODE" >/dev/null 2>&1 < /dev/null & ;;
  off) swaymsg '[app_id="ottoman-saver"] kill' >/dev/null ;;
esac

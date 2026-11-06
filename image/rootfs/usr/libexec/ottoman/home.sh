#!/bin/bash
# Home key: hide every app window to the scratchpad (apps keep running) and bring the shell forward.
# The shell does it (Sway::hideAll): hiding a fullscreen window must be "fullscreen disable" and "move scratchpad" as
# two IPC messages, or sway 1.11 keeps drawing the hidden window at the origin (docs/DESIGN.md 4.15, 2026-11-06).
# The swaymsg lines below are the fallback for when the shell is not on the bus (crashed, restarting).
busctl --user --timeout=3s call org.ottoman.Shell /Shell org.ottoman.Shell Home >/dev/null 2>&1 && exit 0
swaymsg '[app_id="^(?!ottoman-shell$).+"] fullscreen disable' >/dev/null
swaymsg '[app_id="^(?!ottoman-shell$).+"] move scratchpad' >/dev/null
swaymsg '[app_id="ottoman-shell"] fullscreen enable, focus' >/dev/null

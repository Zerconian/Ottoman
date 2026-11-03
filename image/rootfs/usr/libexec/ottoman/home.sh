#!/bin/bash
# Home key: hide every non-shell window to the scratchpad (apps keep running) and bring the shell forward.
swaymsg '[app_id="^(?!ottoman-shell$).+"] move scratchpad' >/dev/null
swaymsg '[app_id="ottoman-shell"] scratchpad show, fullscreen enable, focus' >/dev/null

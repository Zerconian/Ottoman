#!/bin/bash
# Home key: hide every non-shell window to the scratchpad (apps keep running) and bring the shell forward.
swaymsg '[app_id="^(?!ottoman-shell$).+"] move scratchpad' >/dev/null
swaymsg '[app_id="ottoman-shell"] scratchpad show, fullscreen enable, focus' >/dev/null
# Tell the shell too: when it is already the active window no activation event fires, and Home must still reset it.
busctl --user call org.ottoman.Shell /Shell org.ottoman.Shell Home >/dev/null 2>&1 || true

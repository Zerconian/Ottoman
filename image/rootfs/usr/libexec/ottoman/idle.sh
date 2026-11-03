#!/bin/bash
# Idle policy (DESIGN.md 4.10 #7): screensaver after SAVER_SECS, display off after OFF_SECS, the box never
# suspends. swayidle honours idle inhibitors, so a playing app (D-Bus ScreenSaver / Wayland idle-inhibit)
# blocks both. Defaults 300/1800; ~/.config/ottoman/idle.conf may override (tests use small values).
# No -w: it makes swayidle wait for the timeout command to exit, and the screensaver never exits
# (2026-11-03: everything after the first screensaver stalled). Actions are scripts, so no shell quoting.
SAVER_SECS=300; OFF_SECS=1800
[ -f "$HOME/.config/ottoman/idle.conf" ] && . "$HOME/.config/ottoman/idle.conf"
# Each command is ONE argument to swayidle (an unquoted "saver.sh on" made it exit at session start, 2026-11-03).
exec swayidle \
  timeout "$SAVER_SECS" "/usr/libexec/ottoman/saver.sh on"  resume "/usr/libexec/ottoman/saver.sh off" \
  timeout "$OFF_SECS"   "/usr/libexec/ottoman/dpms.sh off"  resume "/usr/libexec/ottoman/dpms.sh on"

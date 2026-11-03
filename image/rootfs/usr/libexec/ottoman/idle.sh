#!/bin/bash
# Idle policy (DESIGN.md 4.10 #7): screensaver after SAVER_SECS, display off after OFF_SECS, the box never
# suspends. swayidle honours idle inhibitors, so a playing app (D-Bus ScreenSaver / Wayland idle-inhibit)
# blocks both. Defaults 300/1800; ~/.config/ottoman/idle.conf may override (tests use small values).
SAVER_SECS=300; OFF_SECS=1800
[ -f "$HOME/.config/ottoman/idle.conf" ] && . "$HOME/.config/ottoman/idle.conf"
exec swayidle -w \
  timeout "$SAVER_SECS" '/usr/libexec/ottoman/ottoman-shell --saver' \
         resume 'swaymsg "[app_id=\"ottoman-saver\"] kill"' \
  timeout "$OFF_SECS" 'swaymsg "output * power off"' \
         resume 'swaymsg "output * power on"'

#!/bin/bash
# dpms.sh on|off: display power for every output. Called by swayidle.
swaymsg "output * power $1" >/dev/null

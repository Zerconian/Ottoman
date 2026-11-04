#!/bin/bash
# Launch Plezy in its TV layout (DESIGN.md 4.15). Plezy keeps "Force TV mode" as the boolean force_tv_mode in its
# shared preferences file (key measured from the 2.25.0 app binary, 2026-11-04).
# Measured 2026-11-04 on the VM: the TV layout's Jellyfin/Emby sign-in form drops typed letters (the keys reach the app
# over Wayland; the desktop layout takes them). So the first launches run the desktop layout, where a keyboard can sign in
# (Tab moves focus, typing works; Plex signs in by QR code in either layout), and the TV layout is forced from the first
# launch after a profile exists (active_app_profile_id is written at sign-in). The user can still change the layout inside
# Plezy; the setting is re-applied only when it is False.
set -u
P=${XDG_DATA_HOME:-$HOME/.local/share}/com.edde746.plezy; F=$P/shared_preferences.json
mkdir -p "$P"
python3 - "$F" <<'PY'
import json, sys, os
f = sys.argv[1]
try: d = json.load(open(f))
except Exception: d = {}
signed_in = bool(d.get("active_app_profile_id"))
want = signed_in
if d.get("force_tv_mode") is not want and (want or "force_tv_mode" in d):
    d["force_tv_mode"] = want
    tmp = f + ".tmp"; json.dump(d, open(tmp, "w")); os.replace(tmp, f)
    print(f"plezy.sh: force_tv_mode set to {want} (signed in: {signed_in})", flush=True)
PY
exec "${PLEZY_BIN:-/usr/bin/plezy}" "$@"

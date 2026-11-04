#!/bin/bash
# Launch Plezy in its TV layout (DESIGN.md 4.15): Plezy keeps "Force TV mode" as the boolean force_tv_mode in its
# shared preferences file (key measured from the 2.25.0 app binary, 2026-11-04). Set it before every start so the
# 10-foot layout is the default on a TV box; the user can still change it inside Plezy and it stays until the next launch.
set -u
P=${XDG_DATA_HOME:-$HOME/.local/share}/com.edde746.plezy; F=$P/shared_preferences.json
mkdir -p "$P"
python3 - "$F" <<'PY'
import json, sys, os
f = sys.argv[1]
try: d = json.load(open(f))
except Exception: d = {}
if d.get("force_tv_mode") is not True:
    d["force_tv_mode"] = True
    tmp = f + ".tmp"; json.dump(d, open(tmp, "w")); os.replace(tmp, f)
    print("plezy.sh: force_tv_mode set", flush=True)
PY
exec /usr/bin/plezy "$@"

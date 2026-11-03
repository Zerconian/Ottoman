#!/bin/bash
# Launch Jellyfin Desktop in TV layout. Its `--tv` flag only sets main.layout in the profile config; the web
# client obeys main.webMode, which defaults to "desktop" (zerc hit this live, 2026-11-03: arrows scroll,
# nothing focuses). The default profile is created here with webMode=tv before the first launch, and an
# existing profile is patched if it drifted.
set -u
D="$HOME/.var/app/org.jellyfin.JellyfinDesktop/data/jellyfin-desktop"
mkdir -p "$D/profiles"
if [ ! -f "$D/profiles.json" ]; then
  ID=$(python3 -c 'import uuid; print(uuid.uuid4().hex)')
  mkdir -p "$D/profiles/$ID"
  printf '{\n    "defaultProfile": "%s"\n}\n' "$ID" > "$D/profiles.json"
  # A partial config gets rewritten with webMode=desktop on launch (measured 2026-11-03); a complete one is kept.
  cp /usr/share/ottoman/jellyfin-desktop.conf.template "$D/profiles/$ID/jellyfin-desktop.conf"
  echo "jellyfin: created profile $ID from the TV-mode template" >&2
else
  ID=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["defaultProfile"])' "$D/profiles.json")
  C="$D/profiles/$ID/jellyfin-desktop.conf"
  if [ -f "$C" ]; then
    python3 - "$C" <<'PY'
import json, sys
p = sys.argv[1]; c = json.load(open(p)); m = c.setdefault("sections", {}).setdefault("main", {})
if m.get("webMode") != "tv" or m.get("layout") != "tv":
    m["webMode"] = "tv"; m["layout"] = "tv"; json.dump(c, open(p, "w"), indent=4); print("jellyfin: profile patched to webMode=tv", file=sys.stderr)
PY
  fi
fi
exec flatpak --user run org.jellyfin.JellyfinDesktop --tv --fullscreen "$@"

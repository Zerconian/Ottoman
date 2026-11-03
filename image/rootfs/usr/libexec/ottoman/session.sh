#!/bin/bash
# M1 session: ensure Flathub + Jellyfin Media Player exist (user install, first boot only), then run it.
# Anything that fails drops to a terminal so the box is never a black screen. Errors go to the journal.
set -u
APP=com.github.iwalton3.jellyfin-media-player
log() { printf 'ottoman-session: %s\n' "$*" >&2; }

for i in $(seq 1 60); do
  nm-online -q -t 1 2>/dev/null && break
  sleep 1
done

if ! flatpak --user info "$APP" >/dev/null 2>&1; then
  log "installing $APP from Flathub (first boot)"
  flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
    || log "flathub remote-add failed"
  flatpak --user install -y --noninteractive flathub "$APP" \
    || log "install of $APP failed"
fi

if flatpak --user info "$APP" >/dev/null 2>&1; then
  exec flatpak --user run "$APP" --fullscreen
fi

log "falling back to a terminal"
exec foot

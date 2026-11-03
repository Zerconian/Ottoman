#!/bin/bash
# Session client, started by sway (sway.config exec). M1/M2.0: ensure Flathub + Jellyfin Desktop exist
# (user install, first boot only), then run it. The M2 launcher replaces this script as the persistent client.
# Anything that fails drops to a terminal so the box is never a black screen. Errors go to the journal.
set -u
log() { printf 'ottoman-session: %s\n' "$*" >&2; }
# Only the Flathub remote is provisioned here; the launcher's first-run screen installs the default apps one by
# one with visible status (zerc, 2026-11-03: land in a usable UI, no apps appearing out of nowhere).
for i in $(seq 1 60); do nm-online -q -t 1 2>/dev/null && break; sleep 1; done
flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || log "flathub remote-add failed"
log "provisioning done"

# Ottoman

A minimal, remote-first TV OS for leftover x86-64 mini PCs: the Android TV feel without Android.
Fedora bootc image, sway kiosk, a Qt launcher with Jellyfin rows, Flatpak apps, a phone web remote,
screensaver and display-off, and automatic rollback when an update does not boot.

Start at `docs/DESIGN.md` (decisions, what is proven, what is not). Working name until 2026-11-02 was Anybox.

## What it is not
It is not a 4K streaming box. Linux gets Widevine L3, so Netflix, Disney+ and Max top out around
1080p here; the tiles say so. Local media (Jellyfin, Plex, Kodi), YouTube and emulation are the point.

## Layout
- `image/` the OS image: `Containerfile`, `rootfs/` (units, sway config, scripts, greenboot check), dev
  customizations for test disks (`bib-config.dev.toml`), a deliberately broken image for the rollback test.
- `shell/` the launcher (`ottoman-shell`, Qt 6 / QML) and its screensaver mode.
- `inputd/` the input daemon: phone web remote on port 18820, gamepads, a virtual keyboard.
- `scripts/` build and test loop: `build-shell.sh`, `build-image.sh`, `registry.sh`, `make-disk.sh`,
  `vm-run.sh`, `vm-update.sh`, `vm-ui.sh`, `vm-type.sh`, `test-rollback.sh`.

## Dev loop (<build-host>)
1. `scripts/build-shell.sh` compiles the launcher in a builder container and runs an isolated load check.
2. `scripts/build-image.sh` builds the bootc image; `scripts/registry.sh push` puts it in the local registry.
3. `scripts/vm-update.sh` pulls it into the test VM and reboots. `scripts/vm-ui.sh` drives the UI one key
   at a time and prints the launcher's state from the journal.
A first disk needs root: `sudo scripts/make-disk.sh` (qcow2) or `sudo TYPE=anaconda-iso scripts/make-disk.sh`.

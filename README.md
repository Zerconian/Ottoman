# Ottoman

A minimal, remote-first TV OS for leftover x86-64 mini PCs: the Android TV feel without Android.
A Fedora bootc image, a sway kiosk, a Qt launcher with Jellyfin rows, Flatpak apps, a phone web remote,
screensaver and display-off, unattended updates with automatic rollback when an update does not boot.

Start at `docs/DESIGN.md`: every decision, what is proven on which hardware, and what is not.

## Status
Early. Everything in the design doc marked proven has been proven on virtual machines; the first real box
(a Haswell-era Lenovo Tiny) is next. Expect rough edges and read the design doc before installing on anything
you care about. The installer wipes the whole disk it is pointed at.

## What it is not
It is not a 4K streaming box. Linux gets Widevine L3, so Netflix, Disney+ and the like top out around 1080p;
the tiles say so. Local media (Jellyfin, Plex, Kodi), YouTube, free streaming sites and emulation are the point.

## Install
1. Download the latest `ottoman-<date>-<sha>-netinstall.iso` from the Releases page and write it to a USB stick
   (`dd`, Fedora Media Writer, balenaEtcher, anything that writes raw images).
2. Plug the box into wired network and boot from the stick. The installer pulls the OS image (about 1.7 GB)
   from `ghcr.io/zerconian/ottoman:stable`, installs it unattended onto the first disk and reboots.
3. First run: pick a language, confirm the network, wait while the default apps install, land on the launcher.
   Open `http://<box>:18820/` on a phone for the remote.

An offline installer that embeds the image (about 2.8 GB) can be built locally: `OFFLINE=1 scripts/release.sh`
on a machine with the `make-disk.sh` sudo rule, or `sudo TYPE=anaconda-iso scripts/make-disk.sh` for a dev build.

## Layout
- `image/` the OS image: `Containerfile`, `rootfs/` (units, sway config, scripts, greenboot check),
  `installer/` (kickstart, anaconda overlay), dev customization templates for test disks.
- `shell/` the launcher (`ottoman-shell`, Qt 6 / QML) and its screensaver mode.
- `inputd/` the input daemon: phone web remote on port 18820, gamepads, a virtual keyboard.
- `scripts/` build, release and test loop. `.github/workflows/` builds the image and the installer on GitHub.

## Dev loop
Copy `.ottoman-dev.env.example` to `.ottoman-dev.env` and fill in your login user, this machine's LAN address and
the SSH key test boxes should accept; nothing personal lives in git.
1. `scripts/build-shell.sh` compiles the launcher in a builder container and runs an isolated load check.
2. `scripts/build-image.sh` builds the bootc image; `scripts/registry.sh push` puts it in the local registry on :18821.
3. `scripts/vm-update.sh` pulls it into the test VM and reboots. `scripts/vm-ui.sh` drives the UI one key
   at a time and prints the launcher's state from the journal.
A first disk needs root: `sudo scripts/make-disk.sh` (qcow2) or `sudo TYPE=anaconda-iso scripts/make-disk.sh` (ISO).
`scripts/test-install.sh` rehearses a full install from an ISO in QEMU, frame by frame.

## Licence
MIT for everything in this repository. The image is assembled from Fedora and Flathub packages under their own licences.

# Anybox — Design

Working name. zerc has not settled on one (2026-11-02).

**Legend.** Plain items are zerc's decisions. *[proposed]* items are Claude fill-ins awaiting
sign-off. Every *[proposed]* line names the alternatives considered and why they lost, so a reader
can overturn it with the argument in front of them.

## 1. What it is

A minimal, remote-first "TV OS" for leftover x86-64 mini PCs and NUCs: the Android TV / Nvidia
Shield experience without Android, for people who run their own media server.

Decided (zerc, 2026-11-02):
- Run "in a minimalistic way (as much as reasonably possible these days)".
- Plex / Jellyfin / Emby and similar media-server clients are first-class.
- YouTube via a wrapper.
- Netflix / Disney+ / etc. installable on the side "via their flatpak/repo", at whatever quality
  Linux DRM allows.
- Accepted limit: it is "nigh impossible" to fully recreate the Shield; "we can get pretty close".

Not a goal (follows from the DRM ceiling, see §2): 4K/HDR commercial streaming. The UI says so
plainly where a user would expect it, instead of letting them discover 720p by eye.

## 2. The wall we build against: DRM

Linux and every Android-x86 fork get Widevine L3 (software). Netflix, Disney+, Max cap L3 at
roughly 720p-1080p, no HDR. L1 needs a hardware TEE and Google's per-device certification, granted
only to locked-down devices (OSMC, who sell a Linux box, could not get it). The only x86 path to 4K
streaming is Windows + Edge + PlayReady SL3000 on certified Intel hardware.

Consequence: Anybox wins on local media (direct-play 4K HEVC/AV1, HDR, lossless audio
passthrough), live TV, gaming and YouTube. For 4K Netflix the honest advice is "use the TV's own
app or a cheap stick". Memory: `project_drm_ceiling.md`.

## 3. Landscape (searched 2026-11-02)

| Project | Lesson for Anybox |
|---|---|
| LibreELEC | packaging discipline, JeOS footprint; but Kodi-only, no app model |
| Plasma Bigscreen (Plasma 6.7, June 2026) | the UI ambition; but it is a shell on a full Plasma stack |
| Bazzite HTPC / ChimeraOS | image-based atomic OS that boots into a 10-foot UI; prior art for the base |
| MRD Android TV x86 | proves people want this; shows Android-x86 is a maintenance dead end (L3 anyway) |
| webOS OSE | Pi-only in practice |

Detail: memory `project_landscape_2026-11.md`.

## 4. Architecture *[proposed]*

```
 ┌──────────────────────────────────────────────────────────┐
 │ apps (Flatpak, sandboxed): Jellyfin MP · Plex HTPC · Kodi │
 │   Emby Theater · web-app runner (YouTube TV, Netflix…)    │
 │   Steam / RetroArch / Moonlight (optional tier)           │
 ├──────────────────────────────────────────────────────────┤
 │ anybox-shell: QML launcher (home, app rail, now-playing,  │
 │   settings, first-run) · anybox-inputd (CEC/IR/BT/phone   │
 │   remote → one key map) · anybox-updated (bootc + flatpak)│
 ├──────────────────────────────────────────────────────────┤
 │ session: Wayland kiosk compositor (cage; gamescope if HDR │
 │   needs it) · PipeWire · NetworkManager · bluez           │
 ├──────────────────────────────────────────────────────────┤
 │ base: Fedora bootc image (fedora-bootc, not a desktop     │
 │   spin) · mesa/VA-API · kernel · Flatpak                  │
 └──────────────────────────────────────────────────────────┘
```

### 4.1 Base OS *[proposed: Fedora bootc image]*
- **Chosen:** a `bootc` image built from `quay.io/fedora/fedora-bootc` with a Containerfile. Atomic
  A/B updates with rollback, image signed and pulled from a registry, Flatpak native, current
  Intel/AMD graphics stack. Bazzite/Universal Blue prove the model for living-room boxes.
- Lost: **Buildroot (LibreELEC-style)**: smallest footprint, but no Flatpak, every app is a
  hand-built add-on; kills the "install Netflix from their flatpak" goal. **Debian/Ubuntu minimal +
  kiosk session**: familiar, but package updates break like a desktop and there is no rollback.
  **Android-x86 fork**: real Android TV apps, but hardware support lags, still L3, enormous
  maintenance; MRD Team's bug list is the evidence.
- "Minimal" is measured, not felt: targets in §8.

### 4.2 Compositor *[proposed: cage, gamescope as fallback]*
- `cage` (wlroots kiosk) shows the newest toplevel fullscreen: launcher behind, app on top, app
  exits and the launcher is back. Tiny. Open question: HDR passthrough and VRR on wlroots in
  the shipped Fedora version; if it lacks them, `gamescope` (Valve's compositor, built for TVs and
  controllers, does HDR/VRR/scaling) hosts the launcher as its primary app. Decide by measurement in
  M1 on real hardware.

### 4.3 Shell *[proposed: own QML launcher]*
- A Qt 6 / QML app. QML has remote-style focus navigation built in, is GPU-accelerated and idles
  around 60-100 MB; Android TV's leanback layout (rows of cards, left rail) maps directly.
- Lost: **Plasma Bigscreen**: ready UI, but pulls in Plasma and we do not own the UX; revisit if our
  launcher stalls. **Kodi as shell**: proven, but launching external Wayland apps from Kodi is
  clunky and the result is "Kodi", not a TV OS. **Steam Big Picture**: polished, but a Steam UI.
  **Web-tech launcher (Electron/Chromium kiosk)**: would share one engine with the streaming
  wrappers, but idles at 300 MB+ and fights the minimal target.
- Dark-first with a light theme, dense where density helps (settings, library), 10-foot type sizes.

### 4.4 App model *[proposed: Flathub + curated TV-ready tier]*
- Flatpak only. Two tiers: **TV-ready** (we test D-pad/remote navigation, launch args, exit
  behaviour; shown in the store UI) and **Everything else** (Flathub search behind a toggle, with
  "untested with a remote" on each card).
- TV-ready seed list: Jellyfin Media Player, Plex HTPC, Kodi, Emby Theater (no official Flatpak;
  we may have to package it), Moonlight, RetroArch, Steam (optional tier, needs the gaming GPU
  path), Firefox or Chromium (keyboard-ish; "with a remote this is rough").

### 4.5 YouTube and streaming wrappers *[proposed: one web-app runner]*
- `anybox-webapp`: a Chromium-based (or WebKitGTK; measure Widevine availability) kiosk runner that
  opens a site fullscreen with a TV user agent and maps remote keys to the site's keys. YouTube uses
  `youtube.com/tv` (the leanback UI YouTube ships to smart TVs); Netflix/Disney+/Max open their web
  players with the Widevine CDM, capped at L3 quality, and the card says so.
- Lost: FreeTube/Invidious (no leanback UI, no account), Kodi YouTube add-on (API-quota pain).
- ToS note: UA spoofing for youtube.com/tv is a grey area that every third-party TV wrapper shares.

### 4.6 Input *[proposed: one daemon, Android-TV key map]*
- `anybox-inputd` normalises HDMI-CEC (libcec; most PCs need a Pulse-Eight USB adapter, a few NUCs
  have a header), IR (kernel `rc` + ir-keytable), Bluetooth remotes and gamepads (bluez), and a
  phone web remote served on the LAN, into one key set: DPAD, OK, Back, Home, Menu, Play/Pause,
  volume. Apps see standard keyboard/gamepad events.

### 4.7 Hardware floor *[proposed]*
- Intel 7th gen+ or AMD Ryzen APU (HEVC 10-bit + VP9 decode via VA-API); AV1 on Intel 11th gen+
  / RDNA2+. NVIDIA secondary (nouveau/NVK first; proprietary driver as an opt-in layer). 4 GB RAM,
  16 GB disk. HDMI audio passthrough (TrueHD/DTS-HD) via PipeWire; verify in Kodi and Jellyfin MP.

### 4.8 Updates and distribution *[proposed]*
- OS: `bootc upgrade` on a timer, apply on next boot, automatic rollback on failed boot; the UI
  shows "update ready, restarts when you turn it off". Apps: Flatpak auto-update.
- Build: Gitea Actions builds the image and an installer ISO (`bootc-image-builder`); image in
  Gitea's registry for development, a public registry when there is a public release.
- Public faces never advertise component versions (zerc's rule); the About screen is local.

## 5. Open questions (batch 1, 2026-11-02)

See the chat batch of the same date; answers land here as decided items.

1. Base OS (§4.1). 2. Shell: build vs adopt Bigscreen (§4.3). 3. Streaming wrappers: ship them
or leave them to the user (§4.5). 4. First target hardware: which box does zerc have spare. 5.
Gaming tier in v1 or later. 6. Name: keep "Anybox" (collides with an existing Mac bookmark app and
a hardware brand) or pick another.

## 6. Ports *[proposed]*

Anybox block **18820-18829**. Taken nearby: 18790-18792 RailgunRun; 18800-18809 claimed by the <private-domain> redesign brain, and zerc says 18800 is Panoptes (2026-11-02; the Panoptes brain records 9600 on Citadel). Either way Anybox stays clear of 1880x. 18820 phone
remote + local settings web UI, 18821 shell API. Bind failure is fatal, never hop.

## 7. Build order *[proposed]*

| M | Deliverable | Proof |
|---|---|---|
| M0 | this doc signed off | zerc's answers recorded |
| M1 | bootc image boots to cage + Jellyfin Media Player on a VM and one real box | boot time, idle RAM, direct-play 4K HEVC measured |
| M2 | QML launcher: app grid, launch/exit Flatpaks, back-to-home | remote-only walkthrough, no keyboard |
| M3 | inputd: CEC, IR, BT, phone remote | each path drives the M2 walkthrough |
| M4 | web-app runner: YouTube TV, one Widevine site | playback + the quality cap shown |
| M5 | first-run (Wi-Fi, display, audio), updates + rollback UX | pull a bad image, watch it roll back |
| M6 | installer ISO, docs | fresh install on the real box from the ISO |

## 8. Minimal, measured *[proposed targets]*

| Metric | Target | Where measured |
|---|---|---|
| Idle RAM at launcher | < 600 MB | real box, `free -m` after 5 min |
| Cold boot to launcher | < 15 s on SATA SSD | `systemd-analyze` + stopwatch |
| Image size | < 3 GB | registry manifest |
| Running services at idle | < 25 | `systemctl list-units --state=running` |

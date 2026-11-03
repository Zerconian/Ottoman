# Ottoman — Design

Named **Ottoman** by zerc, 2026-11-02 ("Ottoman is fine enough"): the furniture in front of the couch, with OTT (over-the-top streaming) built into the word. Working name before that was Anybox.

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
- Base OS, shell and streaming wrappers: zerc delegated the pick to Claude (2026-11-02: "you pick
  the best one that fits the bill", "I'll defer to your choice"). Those items below are therefore
  **decided (delegated)**, overturnable by zerc at any time.
- Gaming: "defer to Steam to handle that since it literally does it all already"; RetroArch-level
  emulation is as far as this variant goes (zerc, 2026-11-02).
- First target box: zerc's Lenovo Tiny, 2c/4t Intel on DDR3, 8-16 GB (§4.7).

Not a goal (follows from the DRM ceiling, see §2): 4K/HDR commercial streaming. The UI says so
plainly where a user would expect it, instead of letting them discover 720p by eye.

## 2. The wall we build against: DRM

Linux and every Android-x86 fork get Widevine L3 (software). Netflix, Disney+, Max cap L3 at
roughly 720p-1080p, no HDR. L1 needs a hardware TEE and Google's per-device certification, granted
only to locked-down devices (OSMC, who sell a Linux box, could not get it). The only x86 path to 4K
streaming is Windows + Edge + PlayReady SL3000 on certified Intel hardware.

Consequence: Ottoman wins on local media (direct-play 4K HEVC/AV1, HDR, lossless audio
passthrough), live TV, gaming and YouTube. For 4K Netflix the honest advice is "use the TV's own
app or a cheap stick". Memory: `project_drm_ceiling.md`.

## 3. Landscape (searched 2026-11-02)

| Project | Lesson for Ottoman |
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
 │ ottoman-shell: QML launcher (home, app rail, now-playing,  │
 │   settings, first-run) · ottoman-inputd (CEC/IR/BT/phone   │
 │   remote → one key map) · ottoman-updated (bootc + flatpak)│
 ├──────────────────────────────────────────────────────────┤
 │ session: Wayland kiosk compositor (cage; gamescope if HDR │
 │   needs it) · PipeWire · NetworkManager · bluez           │
 ├──────────────────────────────────────────────────────────┤
 │ base: Fedora bootc image (fedora-bootc, not a desktop     │
 │   spin) · mesa/VA-API · kernel · Flatpak                  │
 └──────────────────────────────────────────────────────────┘
```

### 4.1 Base OS: Fedora bootc image (decided, delegated 2026-11-02)
- **Chosen:** a `bootc` image built from `quay.io/fedora/fedora-bootc` with a Containerfile. Atomic
  A/B updates with rollback, image signed and pulled from a registry, Flatpak native, current
  Intel/AMD graphics stack. Bazzite/Universal Blue prove the model for living-room boxes.
- Lost: **Buildroot (LibreELEC-style)**: smallest footprint, but no Flatpak, every app is a
  hand-built add-on; kills the "install Netflix from their flatpak" goal. **Debian/Ubuntu minimal +
  kiosk session**: familiar, but package updates break like a desktop and there is no rollback.
  **Android-x86 fork**: real Android TV apps, but hardware support lags, still L3, enormous
  maintenance; MRD Team's bug list is the evidence. **Arch**: zerc offered it; rolling and lean,
  but no atomic A/B update and rollback without building that machinery ourselves, and a rolling
  base on an appliance means every update is a gamble with no safety net. Fedora ships `bootc`,
  `bootc-image-builder` and a current mesa/VA-API stack; its x86-64-v2 baseline runs Haswell.
- "Minimal" is measured, not felt: targets in §8.

### 4.2 Compositor *[proposed: cage, gamescope as fallback]*
- `cage` (wlroots kiosk) shows the newest toplevel fullscreen: launcher behind, app on top, app
  exits and the launcher is back. Tiny. Open question: HDR passthrough and VRR on wlroots in
  the shipped Fedora version; if it lacks them, `gamescope` (Valve's compositor, built for TVs and
  controllers, does HDR/VRR/scaling) hosts the launcher as its primary app. Decide by measurement in
  M1 on real hardware.

### 4.3 Shell: own Qt/QML launcher (decided, delegated 2026-11-02)
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

### 4.5 YouTube and streaming wrappers: one web-app runner (decided, delegated 2026-11-02)
- `ottoman-webapp`: a Chromium-based (or WebKitGTK; measure Widevine availability) kiosk runner that
  opens a site fullscreen with a TV user agent and maps remote keys to the site's keys. YouTube uses
  `youtube.com/tv` (the leanback UI YouTube ships to smart TVs); Netflix/Disney+/Max open their web
  players with the Widevine CDM, capped at L3 quality, and the card says so.
- Lost: FreeTube/Invidious (no leanback UI, no account), Kodi YouTube add-on (API-quota pain).
- ToS note: UA spoofing for youtube.com/tv is a grey area that every third-party TV wrapper shares.

### 4.6 Input *[proposed: one daemon, Android-TV key map]*
- `ottoman-inputd` normalises HDMI-CEC (libcec; most PCs need a Pulse-Eight USB adapter, a few NUCs
  have a header), IR (kernel `rc` + ir-keytable), Bluetooth remotes and gamepads (bluez), and a
  phone web remote served on the LAN, into one key set: DPAD, OK, Back, Home, Menu, Play/Pause,
  volume. Apps see standard keyboard/gamepad events.

### 4.7 Hardware: the floor is zerc's box

**Target box (zerc, 2026-11-02):** a Lenovo Tiny, "some weird 2c/4t Intel series on DDR3", 8-16 GB.
DDR3 + 2c/4t in a Lenovo Tiny shell points at a ThinkCentre M73 / M93p Tiny with a Haswell
Core i3-4130T/4150T/4160T and HD Graphics 4400 (Lenovo's M73 Tiny spec sheet lists exactly those).
*[to confirm: `lscpu | grep 'Model name'` on the box, or the model label.]*

What Haswell means, from Intel's media capabilities (not the search engine's guess):
- Hardware decode: H.264 (and MPEG-2, VC-1) via VA-API. **No HEVC, no VP9, no AV1** in hardware;
  those decode in software. 2c/4t handles 1080p HEVC 8-bit in software at best; 4K HEVC does not play.
- Output: HDMI 1.4a (4K at 30 Hz) and DisplayPort 1.2 (4K at 60 Hz). **No HDR.**
- So on this box the media server transcodes anything that is not H.264, which is exactly the
  "leftover box" audience and a good floor to design for.

Tiers *[proposed]*:

| Tier | Hardware | What plays direct |
|---|---|---|
| Floor | x86-64-v2, any VA-API H.264 decoder (Haswell, zerc's box) | 1080p H.264; everything else server-transcoded |
| Good | Intel Kaby Lake (7th gen) + / AMD Ryzen APU, HDMI 2.0 | 4K HEVC 10-bit, VP9, HDR10 |
| Best | Intel 11th gen + / RDNA2 +, HDMI 2.1 | adds AV1, 4K120 |

4 GB RAM and 16 GB disk minimum. NVIDIA secondary (nouveau/NVK first; proprietary driver as an
opt-in layer). HDMI audio passthrough (TrueHD/DTS-HD) via PipeWire; verify in Kodi and Jellyfin MP
on a box that has it (zerc's Tiny has no receiver path to test, so this waits for other hardware).
M1 measures boot time, idle RAM and 1080p H.264 direct-play on the Tiny; 4K/HDR claims wait for a
Good-tier box.

### 4.8 Updates and distribution *[proposed]*
- OS: `bootc upgrade` on a timer, apply on next boot, automatic rollback on failed boot; the UI
  shows "update ready, restarts when you turn it off". Apps: Flatpak auto-update.
- Build: Gitea Actions builds the image and an installer ISO (`bootc-image-builder`); image in
  Gitea's registry for development, a public registry when there is a public release.
- Public faces never advertise component versions (zerc's rule); the About screen is local.

### 4.9 Gaming: defer to Steam (decided 2026-11-02)
- No Steam integration, no gamescope session, no GPU-driver matrix. Steam's own boxes and the Steam
  Frame do that already; "reinventing the wheel seems dubious" (zerc).
- RetroArch (Flatpak) in the TV-ready tier for emulation; that is the ceiling for this variant.
- *[proposed]* Steam Link and Moonlight clients in the TV-ready tier: they stream from a gaming PC,
  cost nothing to support, and are the literal form of "defer to Steam".

## 5. Open questions

### Batch 1 (2026-11-02): answered
1. Base OS: delegated, Fedora bootc (§4.1). 2. Shell: delegated, own QML launcher (§4.3).
3. Wrappers: delegated, one web-app runner (§4.5). 4. Target box: Lenovo Tiny, Haswell-class (§4.7).
5. Gaming: defer to Steam, RetroArch only (§4.9). 6. Name: decide first, then zerc recreates the repo
under the new name and the working directory moves.

### Batch 2 (2026-11-02): open
- Name (shortlist in chat; collisions checked 2026-11-02: no OS/distro named Ottoman, Tenfoot,
  Mantel or Divan; "Plinth" was FreedomBox's old UI name; "Anybox" is a Mac bookmark manager).
- Confirm the Tiny's CPU model.

## 5a. Batch 1 original list (2026-11-02)

See the chat batch of the same date; answers land here as decided items.

1. Base OS (§4.1). 2. Shell: build vs adopt Bigscreen (§4.3). 3. Streaming wrappers: ship them
or leave them to the user (§4.5). 4. First target hardware: which box does zerc have spare. 5.
Gaming tier in v1 or later. 6. Name: keep "Anybox" (collides with an existing Mac bookmark app and
a hardware brand) or pick another.

## 6. Ports *[proposed]*

Ottoman block **18820-18829**. Taken nearby: 18790-18792 RailgunRun; 18800-18809 claimed by the <private-domain> redesign brain, and zerc says 18800 is Panoptes (2026-11-02; the Panoptes brain records 9600 on Citadel). Either way Ottoman stays clear of 1880x. 18820 phone
remote + local settings web UI, 18821 shell API. Bind failure is fatal, never hop.

## 7. Build order *[proposed]*

| M | Deliverable | Proof |
|---|---|---|
| M0 | this doc signed off | zerc's answers recorded |
| M1 | bootc image boots to cage + Jellyfin Media Player on a VM and the Lenovo Tiny | boot time, idle RAM, 1080p H.264 direct-play measured on the Tiny |
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

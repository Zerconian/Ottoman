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
- TV-ready seed list (Flathub IDs confirmed live 2026-11-02): Jellyfin Desktop
  `org.jellyfin.JellyfinDesktop` (2.0.0; Flathub renamed it from `com.github.iwalton3.jellyfin-media-player`, found on the first VM boot), Plex HTPC `tv.plex.PlexHTPC`, Kodi
  `tv.kodi.Kodi`, RetroArch `org.libretro.RetroArch`, Steam Link `com.valvesoftware.SteamLink`,
  Moonlight `com.moonlight_stream.Moonlight`. Emby Theater has no official Flatpak; we may have to
  package it. Browser: Firefox or Chromium, labelled "rough with a remote".

### 4.5 YouTube and streaming wrappers: one web-app runner (decided, delegated 2026-11-02; YouTube revised 2026-11-03)
- **YouTube = VacuumTube** (`rocks.shy.VacuumTube` on Flathub, 2.0.1 as of 2026-11-03): a maintained open-source wrapper of YouTube Leanback for PCs with remote/gamepad support and an ad blocker. It replaces the YouTube half of the runner; writing our own would duplicate it. Joins the TV-ready catalogue.
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
- VA-API driver: Haswell needs the legacy **i965** driver (`libva-intel-driver`); the modern iHD
  driver (`intel-media-driver`) starts at Broadwell. The image ships both and libva picks per GPU.
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

### 4.10 Launcher (M2) — decided by zerc in Q&A, 2026-11-03

| # | Question | Decision |
|---|---|---|
| 1 | Home screen shape | **Shield-style rows:** header (clock, settings, power), APPS row, then content rows (Continue watching, Recently added) |
| 2 | Home / Back | **Home suspends the app** (keeps running behind the launcher, tile shows a running dot, resume is instant); **Back always goes to the app.** Launcher caps background apps at one or two and closes the oldest. *[proposed, implemented 2026-11-03]* Home also resets the launcher itself: overlays (Settings, Add app, tile menu, sign-in, keyboard) close and the APPS row takes focus, as on Android TV |
| 3 | Settings v1 | **Network (Wi-Fi join, on-screen keyboard), display (resolution + refresh), audio (output device, passthrough), updates (check / apply / rollback), About (version, IP, storage).** Remote pairing waits for M3 |
| 4 | Phone web remote | **M3**, with CEC/IR/Bluetooth, one input daemon. M2 is driven by keyboard and gamepad |
| 5 | Content rows | **Jellyfin first:** sign in once from the launcher (password or Quick Connect), token stored, rows filled from the API, selecting an item deep-links into Jellyfin Desktop. Plex/Emby adapters later; their rows show an empty state. **Deep-link mechanism *[proposed]*:** Jellyfin Desktop 2.0 has no item/URL argument (checked `--help` 2026-11-03: only `--tv`, `--fullscreen`, profiles, config-dir, log-level). The shell is itself a Jellyfin client, so it deep-links the Jellyfin way: `POST /Sessions/{jellyfinDesktopSessionId}/Playing?itemIds=X&playCommand=PlayNow`, the same remote-control call the official apps use for cast-to. Launch args: `--tv --fullscreen` |
| 6 | App row | **User-managed from the TV-ready list:** installed TV-ready apps, long-press to move / hide / uninstall, an "Add app" tile at the end installs from the TV-ready list. Flathub-wide search waits for the store screen |
| 7 | Idle | **Screensaver (dim clock/artwork) at 5 min, display off at 30 min, the box never suspends.** A playing app blocks both |
| 8 | First run | **Language (English US preselected, applied system-wide), then Network, then a setup screen** (language added by zerc 2026-11-03; the default-app prefetch starts on the language screen whenever a connection is already up) (revised by zerc 2026-11-03: "land in a UI that's usable vs having to add apps or wait for Jellyfin to magically appear"): one Wi-Fi/wired screen, then "Setting up Ottoman" installs the default apps one by one with visible status, in zerc's priority order (2026-11-03): Jellyfin, Plex, YouTube via VacuumTube, Firefox for the streaming tiles, RetroArch, Steam Link; Kodi and Moonlight stay opt-in, with Retry / Continue anyway on failure, then the launcher. Display, Jellyfin sign-in and extra apps live in Settings |

**Compositor consequence *[proposed]*:** decision 2 needs the shell to raise and lower app windows
on Home, which `cage` cannot do (it only shows the newest toplevel). Options: (a) **sway in kiosk
configuration** (no bar, every window fullscreen, borders off) with the launcher driving it over
sway IPC (`focus`, `kill`, `move scratchpad`); same wlroots stack as cage, so the hardware story is
unchanged. (b) Write the compositor into the launcher with Qt Wayland Compositor on eglfs/KMS:
total control, but eglfs on random mini PCs is less proven than wlroots. (c) labwc, same IPC idea
with a smaller surface but a younger IPC. Pick: **(a) sway**. **M2.0 PROVEN 2026-11-03 09:4x on the VM:** sway 1.11 kiosk session active (0 restarts, 7.0 s boot), Jellyfin Desktop fullscreen (get_tree: fs=1 focused), `move scratchpad` blanks the screen with the process still alive (screendump 432 bytes = black), `scratchpad show, fullscreen enable` restores it (screendump identical to before). Rollback: cage deployment kept by bootc.

**M2 build order *[proposed]*:** M2.0 session = sway kiosk + launcher process + IPC raise/lower proven
on the VM (DONE 2026-11-03). M2.1 home screen: header, APPS row from installed Flatpaks, launch/suspend/resume, running
dot (**DONE 2026-11-03 14:58 UTC on the VM:** screendumps m21-a/b/c; Enter launched Jellyfin Desktop in 3 s, Home put it in the scratchpad still running and the shell came back with the green dot; get_tree: Jellyfin visible=False, shell visible+focused. Shell RSS 194 MB, session 1188 MB used with Jellyfin behind. Known: the APPS row clips at the right edge; xdg-desktop-portal fails to start under sway (needs `xdg-desktop-portal-wlr`), harmless for now). M2.2 Jellyfin sign-in + content rows + deep links (**sign-in + rows PROVEN 2026-11-03 15:15 UTC on the VM** against the dev Jellyfin 12.4 server: password sign-in from the overlay, token saved 0600 in ~/.config/ottoman/jellyfin.conf, Continue watching shows the resumed movie with its progress bar, Recently added shows the rest, posters load; **deep link PROVEN 2026-11-03 15:36 UTC:** Enter on the Continue card logged `play f71dffb3…`, `PlayNow … -> 204`, the dev server's Jellyfin Desktop session reported NowPlayingItem Test Movie 1 with the same id; a second pick from Recently added (2nd card) gave id 7e39b487… = Test Movie 2 playing; Jellyfin Desktop came forward each time. Startup refresh with a stored token fills the rows in 0.2 s. **M2.2 DONE.**) M2.3 Settings (network, display, audio,
updates, about) (**proven on the VM 2026-11-03 16:1x UTC, driven one key at a time with the shell's ui: journal lines:** Network shows the wired IP and "No Wi-Fi adapter"; Display lists the QEMU monitor's modes, setting 3840x2160@50 changed the screendump to 3840x2160 and reverted to 1280x800 after 10 s, set + Enter saved `Virtual-1=3840x2160@50.000Hz` to display.conf, restore saved the original; Updates ran `bootc upgrade --check` through the sudoers allowlist and reported no changes; About shows hostname/kernel/uptime/storage and signs Jellyfin out; the on-screen keyboard opened with F2, typed with the D-pad and closed with Done; sign-out from About and sign-in again from the overlay (server address remembered) refilled the rows. **M2.3 DONE except Audio on real hardware.** Audio shows "No audio outputs found" because the headless VM has no audio device: untested on real hardware. Traps: sway mode syntax needs `@R.RRRHz`; a failed mode set must not arm the keep/revert state). M2.4 first-run (network) + screensaver/display-off (**2026-11-03 16:5x UTC on the VM, idle shortened to 8/20 s:** first-run page shows the wired IP, Continue writes `firstrun-done`; the screensaver window appears after 8 s idle and a key removes it; the output powers off at 20 s and a key powers it on; a playing Jellyfin Desktop did NOT inhibit idle on its own at first (sway tree inhibit_idle=false, swayidle ignores D-Bus ScreenSaver), so the shell now serves org.freedesktop.ScreenSaver itself and also sets `inhibit_idle` on the Jellyfin window from the server's play state. **Re-tested 17:0x UTC: Jellyfin Desktop called Inhibit ("Video Wake Lock"), both windows showed inhibit_idle=true, no screensaver for the whole clip, inhibit released 10 s after it ended and the screensaver returned. M2.4 DONE.** Traps: `swayidle -w` blocks behind a never-exiting screensaver; every swayidle command is one argument). M2.5 app-row management + Add
app (**DONE 2026-11-03 18:3x UTC on the VM:** a 1 s held Enter opens the tile menu and it stays until a real release; Cancel launches nothing; Move left wrote `order=Moonlight, Jellyfin` to apps.conf; Hide wrote `hidden=Moonlight`; Add app listed it as hidden and Enter re-showed it; Add app installed RetroArch and Moonlight from Flathub earlier in the day; Uninstall removed Moonlight (flatpak list confirms). Traps: Qt Wayland emulates auto-repeat as release+press pairs flagged isAutoRepeat; specific key handlers run before the general one; Home must reset the shell over D-Bus when the shell is already active). **M2 COMPLETE.** Each step ships to the VM via the registry and is driven by keyboard/gamepad in QEMU.

## 5. Open questions

### Batch 1 (2026-11-02): answered
1. Base OS: delegated, Fedora bootc (§4.1). 2. Shell: delegated, own QML launcher (§4.3).
3. Wrappers: delegated, one web-app runner (§4.5). 4. Target box: Lenovo Tiny, Haswell-class (§4.7).
5. Gaming: defer to Steam, RetroArch only (§4.9). 6. Name: decide first, then zerc recreates the repo
under the new name and the working directory moves.

### Batch 2 (2026-11-02): name = Ottoman (zerc). Tiny CPU model still open (the mini PCs are in storage until after 2026-11-08).

### Batch 3 (2026-11-03): M2 launcher, eight questions one by one, answers in §4.10.

## 5a. Batch 1 original list (2026-11-02)

See the chat batch of the same date; answers land here as decided items.

1. Base OS (§4.1). 2. Shell: build vs adopt Bigscreen (§4.3). 3. Streaming wrappers: ship them
or leave them to the user (§4.5). 4. First target hardware: which box does zerc have spare. 5.
Gaming tier in v1 or later. 6. Name: keep "Anybox" (collides with an existing Mac bookmark app and
a hardware brand) or pick another.

## 6. Ports *[proposed]*

Ottoman block **18820-18829**. Taken nearby: 18790-18792 RailgunRun; 18800-18809 claimed by a sibling project, and zerc says 18800 is Panoptes (2026-11-02; the Panoptes brain records 9600 on Citadel). Either way Ottoman stays clear of 1880x. 18820 phone
remote + local settings web UI, 18821 shell API. Bind failure is fatal, never hop.

### 4.11a Quiet boot (zerc, 2026-11-03) *[proven 21:17 UTC on the VM, second pass with branding: grub line reads "Booting Ottoman", Plymouth shows the OTTOMAN wordmark over the spinner, initramfs 238 MB after trimming; first pass 21:1x UTC: frames every 2 s through a reboot showed firmware logo, one grub line, the Plymouth spinner, then the launcher at 9.4 s; no kernel or systemd text; greenboot healthy on the 265 MB regenerated initramfs]*
Power-on to launcher shows no grub menu (hidden, zero timeout, Shift opens it), no kernel or systemd
text (`quiet loglevel=3 splash rhgb systemd.show_status=0 vt.global_cursor_off=1`), a Plymouth spinner
from the initramfs (regenerated in the image build with the plymouth module) until the session takes the
display (`ottoman-session.service` after `plymouth-quit-wait`). Out of reach: the firmware's own logo. Installer side
(zerc 2026-11-03, proven by rehearsal 3 frames): `scripts/brand-iso.sh` post-processes bib's ISO, no installer
rebuild: menu countdown 5 s (tree grub.cfg x2 + the EFI boot partition's copy via mtools; the appended EFI
partition is swapped with xorriso), `rhgb` on the installer kernel lines (the systemd wall is gone; two dracut
warning lines at 4 s remain), `images/product.img` = gzip cpio overlay that anaconda's stock
`anaconda_auto_updates` hook unpacks: dark Ottoman sidebar + wordmark; anaconda's title already read
"Ottoman 44 installation" from os-release. Still visible: grub's "Booting 'Install Ottoman 44'" line while the
111 MB installer initrd loads (~38 s on QEMU's virtual CD) and anaconda's 8 s tmux text before its GUI.

### 4.11 Boot waits (zerc, 2026-11-03)
Boot must never wait on DHCP or the internet. `NetworkManager-wait-online.service` is disabled in the
image (nothing in the session is ordered after `network-online.target`); Ottoman's own waits are bounded
(first-boot Flatpak install: 60 s for the network, then it gives up and shows the launcher; greenboot
check: 90 s). Open: zerc saw a dracut line with "no time limit" while the installer ISO booted; the
exact wording is not in the serial log (installer text goes to the VGA console). Screendump the next
installer boot to identify it; it belongs to the anaconda ISO, not the installed system.

### 4.13 Public release path (zerc, 2026-11-04) *[decided; proofs in progress]*
- **Why.** The private Gitea requires sign-in for everything (anonymous API and registry calls get 401/403), so a
  clean install could only update with a pull token baked into every box. zerc: move to GitHub "and just let it
  ride in public for now", with the project disassociated from personal domains and PII.
- **Decided:** GitHub user `Zerconian`, repo `Ottoman`, image `ghcr.io/zerconian/ottoman` (`:edge` on every push
  to main, `:stable` + immutable `:<date>-<sha>` on a release), licence MIT. Gitea stays the origin (LAN SSH, the
  precious copy) and push-mirrors to GitHub; GitHub Actions builds from the mirror (`.github/workflows/build.yml`).
  The "nothing public shows software versions" ruling is consciously excepted for the OS image: a distribution is a
  package list, and the ruling targets services advertising themselves.
- **Installer.** The embedded-image ISO is 2.79 GiB (0.95 GB anaconda runtime + 1.73 GiB of already-gzip image
  blobs + boot files); GitHub release assets stop at 2 GiB and compression cannot bridge that. The public installer
  is therefore the stock Fedora 44 netinstall ISO (1.16 GB) with our kickstart and branding injected
  (`scripts/make-netinst-iso.sh`, no root): `ostreecontainer --transport=registry` pulls the image from ghcr during
  the install, `bootc switch --mutate-in-place` sets the update reference, exactly the mechanism bib's own
  kickstart uses with a local OCI directory. Cost: a wired network during the install. The offline ISO stays a
  local build (`OFFLINE=1 scripts/release.sh`) for LAN installs. Test builds can carry a login user and an
  insecure dev-registry entry for the installer (never shipped).
- **Scrub before the first public push.** The dev user, build-host name, LAN address and SSH key moved out of git
  into `.ottoman-dev.env` (gitignored; `scripts/dev-env.sh` supplies defaults); dev bib configs are templates;
  docs lost the hostname. History: all commits carried a personal e-mail and eleven lines named the private
  hostname or LAN addresses, so the history is rewritten once (author to the GitHub noreply address, hostname and
  addresses to placeholders) into a new repo that becomes the origin; the old repo stays as the private archive.
- **Proofs:** (1) DONE 2026-11-04 17:0x UTC: the netinstall test ISO (dev image from the local registry, test user)
  installed on the VM unattended: "Install finished" on serial at 181 s, ssh at 194 s, first run Language > Network >
  Setup to the launcher with the six default apps at 282 s, `bootc status` image ref `<build-host>:18821/ottoman:dev`
  transport registry, hidden grub, PRETTY_NAME Ottoman (scripts/test-install.sh, 104 frames). Two traps on the way:
  the stock menu defaults to the media check, which fails on a rewritten ISO (default is now the install entry), and
  xorriso refuses to overwrite an existing output (removed first); (2) first push to ghcr by hand from the build host, then the public
  netinstall ISO installs on the VM and `bootc upgrade --check` works with no credential; (3) the GitHub workflow
  goes green on the mirror; (4) the installed test VM follows `ghcr.io/zerconian/ottoman:stable`.

### 4.12 UI polish log
- 2026-11-04 15:4x UTC, UI pass (zerc: "refinement and validation so it's not quite so rough around the edges").
  Audit first: every launcher screen captured on the installed VM at 1920x1080 (the VM had been running at
  1280x800; Settings > Display now holds the 1080p mode). Found and fixed, each with a before/after frame:
  Settings > Display dumped eleven modes with duplicates and pushed the screensaver rows off the page (now
  Display / Resolution / screensaver rows, Resolution opens a deduplicated sub-list centred on the current mode;
  try-for-10-s / Enter-keeps / Back-reverts unchanged); the tile menu, Jellyfin sign-in and Wi-Fi password were
  bare text floating over the dimmed page (one `Dialog` surface now: dim, panel, title, hint); the empty
  Continue row was a blank grey box (tinted plate with the Jellyfin icon, "Your shows and movies land here");
  the Settings button floated between header and rows (header line: wordmark, Jellyfin user, Settings pill,
  clock); row titles were tracked caps ("Apps", "Continue watching" now); moving down scrolled the Apps row
  clean off, leaving an empty screen (the row above now peeks in at 45 % with its name plates whole; scroll
  positions come from the blocks, not fixed numbers); the footer explained the whole UI in one developer sentence
  (one hint for the focused row); the on-screen keyboard covered the field being typed into (it echoes the
  field's label and text along its top); Add app rows ran "up to 1080p (Widevine L3), Enter adds it to the row"
  (now name, "Streams in Firefox, up to 1080p", and On the row / Not on the row / Hidden / Not installed, with the
  action explained once at the bottom); tile notes were 12 px jargon ("Up to 1080p" at 15 px; the Widevine
  mechanism stays in §4.5). Settings and Add app share the page header (title, one-line blurb, lists at y=180)
  and a "Back returns home" corner. Proof: frames before/after at 1080p in the session scratchpad (audit/before1080, after, after2)
  and a driven walk on the installed VM at 15:5x UTC: Resolution opened centred on `1920x1080@60 current`,
  Up x11 reached 1280x800@75, Enter tried it ("reverting in 8 s" frame), the journal shows the revert
  (`set mode Virtual-1 1920x1080@60.000Hz ok`); tile menu Move left wrote `order=tv.plex...` first; Add app >
  Pluto TV wrote `shown=web:tubi, web:plutotv` and its tile appeared; Hide from the row wrote
  `hidden=org.libretro.RetroArch`; the keyboard strip read "Server address qw|" after two OK presses (journal
  `osk press q`, `osk press w`). Not re-proven on the VM: the first-run screens (unchanged apart from the Wi-Fi
  dialog and the shared list rows) and the Wi-Fi join dialog (no Wi-Fi adapter in QEMU).
- Side defect, same hour: the hidden FirstRun page called refresh() on every shell start, which ran
  installDefaults (a Flatpak check per default app, twice per boot in the journal). Now only when the page is
  shown; compiled, not yet proven on a VM boot.
- 2026-11-03 23:5x UTC, screensaver (friend's "animated wallpaper" ask): modes clock / aurora / stars, picked in
  Settings > Display with "Screensaver after" (5/10/30 min/never) and "Display off after" (30/60 min/never) and a
  Preview row; the saver ends on any key release; Settings stays open after a preview. Proven on the installed VM:
  preview frames for aurora and stars, Escape ends it with the Settings row still focused, timing changes rewrite
  idle.conf and restart swayidle (600 seen in its argv; "never" runs a sleeper instead of swayidle).
- 2026-11-03 23:3x UTC, live proofs on the ISO-installed VM (all green): Home Assistant `/power?state=off|on`
  turned the output off and on (sway `get_outputs` power false/true); pointer mode routed Right x3 + OK to the
  virtual mouse with zero launcher key events; Settings > Updates > Check found the pushed image, Download staged
  it (bootc "Queued for next boot"), the page then listed "Ready on next restart", Restart now booted it (About
  shows `commit=cc7d8b3`), old image in the rollback slot, greenboot healthy; Add app > Tubi > Enter put the tile
  on the row (apps.conf `shown=web:tubi`), its tile opened Firefox kiosk on tubitv.com (screendump).
- Defect found and fixed the same hour: order/hidden were keyed by Flatpak ID, so installing Firefox put all 13
  streaming sites on the row and Add app could neither add nor hide one. Now keyed per entry (`web:<slug>`),
  opt-in sites start off the row (`shown` list), Netflix stays by default.
- 2026-11-03 20:5x UTC (zerc, live): Jellyfin Desktop opened in the web client's Desktop layout (arrows scroll, nothing takes focus). Cause: its `--tv` flag only sets `main.layout` in the profile config; the web client obeys `main.webMode`, which defaults to `desktop`, and a partial config file gets rewritten with `desktop` on launch while a complete one is kept. Fix: `jellyfin.sh` creates the default profile from a complete TV-mode template (`/usr/share/ottoman/jellyfin-desktop.conf.template`) before the first launch and patches an existing profile that drifted. The other default apps are 10-foot by design; the streaming sites rely on pointer mode. Rule (zerc): every app must open remote-ready on the first try.
- 2026-11-03 20:39 UTC (zerc, live over krdc): tiles got gradient + sheen + glow backgrounds, icons from the largest shipped size with mipmaps, the quality note centered under the name; the rows no longer clip (the earlier `topMargin` padding only affects vertical lists, so the focused tile kept bleeding at the top). Screendump tile-1: outline complete on all sides. Prefetch proven the same minute: "firstrun prefetch start" then "setup done, failed 0" because everything was already installed.
- 2026-11-03 20:36 UTC, proven on a fresh install driven by zerc over krdc: the new first run (network, then the setup screen) installed Jellyfin, Plex, YouTube, Firefox, RetroArch and Steam Link in that order, all exit 0, and landed on the launcher with the apps' own icons, the outline only on the focused tile and no clipping (screendump ux-home). Fixed from that shot: the streaming tiles' quality note collided with the name.
- 2026-11-03 (zerc): tiles carry art instead of flat colour. Installed Flatpaks show their own exported icon (`~/.local/share/flatpak/exports/share/icons/hicolor/<size>/apps/<id>`), which is what that icon ships for; web apps (Netflix, Disney+, Max) get a custom monogram roundel in the service colour, never the service's own mark (zerc: "I know copyright is a pain point"). Names sit below the art.
- 2026-11-03 (zerc, from a screenshot): the focus outline was clipped top/left (tiles scale 6% inside a clipped row starting at its edge: rows now have 12 px inner margins) and a second row showed a highlight without focus (`ListView.isCurrentItem` alone: now `&& row.activeFocus`, so only the item being interacted with is highlighted).

## 6a. Build and test tooling (the build host, 2026-11-02)

Present: podman 5.8.9, Fedora 44, 598 GB free, 16 threads, 31 GB RAM. Base image
`quay.io/fedora/fedora-bootc:44` (tags 43-46 exist; 44 matches the host, rebuilt daily). Fedora 44
packages: cage 0.3.1, gamescope 3.16.x, libcec 7.1.1, intel-media-driver 26.1, qt6 6.10/6.11.
Missing and needing root: `qemu-system-x86-core qemu-img libvirt virt-install bootc` for the VM
smoke test (`! sudo` fails from the Claude prompt; zerc runs it in a terminal). `bootc-image-builder`
runs as a privileged podman container and produces the qcow2/ISO; it needs the above only to boot
the result. Build: `scripts/build-image.sh`, logs in `~/.local/share/claude-scratch/ottoman/`.

## 7. Build order *[proposed]*

| M | Deliverable | Proof |
|---|---|---|
| M0 | this doc signed off | zerc's answers recorded |
| M1 | bootc image boots to cage + Jellyfin Media Player on a VM and the Lenovo Tiny | boot time, idle RAM, 1080p H.264 direct-play measured on the Tiny. **VM half DONE 2026-11-02 23:4x:** QEMU boots to the cage kiosk with Jellyfin Desktop 2.0.0 on screen (screendump), session active with 0 restarts, 6.7 s to multi-user, 763 MB used with the app running, 38 running units; first boot installed app + runtimes from Flathub in 41 s; `bootc switch` from the local registry worked and left the previous deployment as rollback. **Tiny half pending** (ISO + real hardware) |
| M2 | QML launcher: app grid, launch/exit Flatpaks, back-to-home | remote-only walkthrough, no keyboard |
| M3 | inputd: CEC, IR, BT, phone remote | each path drives the M2 walkthrough. **M3.0 DONE 2026-11-03 18:5x UTC:** `ottoman-inputd` (python3-evdev, system service) serves the phone remote page on :18820 and injects keys through a uinput keyboard; from the host via the VM forward, home/down/up moved the shell's focus rows, a held OK on the Jellyfin tile opened the tile menu and Back closed it (shell journal). Gamepad path proven with a uinput-emulated pad inside the VM (HAT down/down/up and BTN_MODE became down/down/up/home in the daemon log and moved the shell's rows, then reset it). CEC, IR and Bluetooth pairing wait for the Tiny (no adapters in the VM). Trap: a test reader that printed nothing made this look broken for an hour |
| M4 | web-app runner: YouTube TV, one Widevine site | playback + the quality cap shown. **M4.0 DONE 2026-11-03 18:4x UTC:** YouTube = VacuumTube launched from its tile (Wayland override applied by the catalogue); the Netflix tile ran `webapp.sh` and Firefox kiosk showed Netflix's sign-in page (screendump w-1), the per-site profile was created, Home returned to the launcher; Widevine L3 proven by the EME probe page; the cap "up to 1080p (Widevine L3)" is on the tiles. Not proven: actual DRM playback on a real account (needs zerc's credentials, his call) |
| M5 | first-run (Wi-Fi, display, audio), updates + rollback UX | pull a bad image, watch it roll back. **DONE 2026-11-03 19:19 UTC on the VM:** greenboot 0.16 + the Ottoman required check; a deliberately broken image (session ExecStart missing) was pushed and upgraded to; greenboot failed the check on 4 consecutive boots (19:12-19:17), then logged "Deployment manager 'bootc' detected, attempting rollback" and "Next boot: rollback deployment"; the 19:19 boot came up on the previous image with the check passing and greenboot-success.target reached; `bootc status` shows the good digest booted and the broken one in the rollback slot. Self-heal took about 7 minutes. Caveats: the grub boot-counter snippet (`08_greenboot.cfg`) is written by bootupd at install time, so this pre-greenboot VM needed it inserted by hand; **a fresh bib disk built by zerc 2026-11-03 14:56 carries it from install (grub.cfg line 72, greenboot enabled, first boot healthy)**. The 8.5 GB default disk could not stage a third deployment until grown: M6 builds need a larger root |
| M6 | installer ISO, docs | fresh install on the real box from the ISO. **Release path decided 2026-11-03 (zerc): Gitea container registry on the private build infrastructure (`<private-gitea>/zerc/ottoman`) (`:stable` + immutable tag), `scripts/release.sh` on the build host now, a CI runner later (none registered yet); the Tiny's first install uses the dev ISO. First release 2026-11-03 23:48 UTC: `docs/RELEASES.md`. Open: the package is private (anonymous pull UNAUTHORIZED), so a clean install cannot update until the package is public or carries a pull token.** **VM HALF DONE: rehearsal 2, 2026-11-03 22:1x UTC (`scripts/test-install.sh`, ISO built from the DEV image under the new make-disk sudo rule):** install 3 min 2 s unattended, first boot 7.7 s, Language > Network > Setup to the launcher in 98 s with all six default apps installed (prefetch had started on the language screen), idle inhibit on/off logged around first run; proofs over ssh: `sudo -n` ok, dev registry conf present, image reference `<build-host>:18821/ottoman:dev` (transport registry), greenboot boot-counter snippet in grub.cfg (7 lines), grub `timeout_style=hidden timeout=0`, PRETTY_NAME Ottoman, greenboot-success + session active, first-run flag written. Remaining for M6: the Tiny install after 2026-11-08; anaconda's own screens stay Fedora-branded (custom product image, parked); the ISO menu's 60 s countdown is bib's default. Rehearsal 1, 21:3x UTC (`scripts/test-install.sh`, ISO built by zerc 16:30 local from the registry-named DEV image):** grub menu "Install Ottoman 44" (60 s countdown, bib default), unattended anaconda install in 3 min 3 s, reboot, first boot 8.4 s to the launcher's first run; Language (English US preselected, Enter) > Network (wired, Enter) > Setup installed all six default apps by about 6 min; launcher up with Jellyfin/Plex/YouTube/Netflix tiles; prefetch footer counted on the language screen. Image reference is the registry name (manifest %post `bootc switch --mutate-in-place`). Missing on that install: passwordless sudo (bib's ISO path ignores `installer.sudo-nopasswd` as well as `customizations.files`: no NOPASSWD in the manifest, sudo prompted) so journal/bootc/grub-snippet proofs were blind; fixed by baking the dev sudo rule and the dev registry entry into DEV=1 images; second ISO + rehearsal pending. Correction: the screensaver at 21:40 was normal idle on the finished launcher, not the setup screen hiding; first run now holds idle anyway for slow installs. Earlier: ISO built by zerc 2026-11-03 14:53 local (`build/disk/bootiso/install.iso`, 2.76 GB, anaconda, dev customizations); README written. ISO booted in a VM 2026-11-03 20:0x: anaconda installed unattended onto a blank 24 GB disk and rebooted into the launcher by itself; greenboot enabled and active on the result; root auto-grown to 22 GB. BUT the anaconda path applied only the user from the dev config, not the `customizations.files` (no sudoers, no insecure-registry entry), and the image reference is the local build name, so that install can neither be updated nor managed over ssh with root; the grub snippet could not be checked without root. M6 must: build from the registry name (make-disk.sh now does), and carry dev/management files via a kickstart `%post` or a dev image variant instead of bib file customizations. Open: the installer must reference the image by its REGISTRY name (a disk built from `localhost/ottoman:dev` installs fine but `bootc upgrade` inside it has nowhere to pull from; found 2026-11-03 20:3x on zerc's fresh disk), and the install on the Tiny. Disk size resolved: bootc grows the root partition at first boot, so only the virtual disk size matters (the 8.5 GB came from bib's default qcow2 size; a 24 GB disk gave a 21 GB root with no action)** |

## 8. Minimal, measured *[proposed targets]*

| Metric | Target | Where measured |
|---|---|---|
| Idle RAM at launcher | < 600 MB | real box, `free -m` after 5 min. **QEMU 2026-11-02: 763 MB used with cage + Jellyfin Desktop (QtWebEngine) running; 438 MB without the compositor.** Over the target: the target was for the launcher alone, so it stands; a QtWebEngine app on top costs ~325 MB |
| Cold boot to launcher | < 15 s on SATA SSD | `systemd-analyze` + stopwatch. **QEMU 2026-11-02: 6.7 s to multi-user on the second boot (kernel 0.6 + initrd 2.7 + userspace 3.4), 8.75 s on the first** |
| Image size | < 3 GB | registry manifest. **M1 measured 2026-11-02: 3.23 GB** (base fedora-bootc:44 is 1.95 GB; 277 packages added, 832 total). Over target; trim is a later milestone |
| Running services at idle | < 25 | `systemctl list-units --state=running`. **QEMU 2026-11-02: 38 running units, over target; trim list is a later milestone** |

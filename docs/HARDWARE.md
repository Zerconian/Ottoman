# Hardware day runbook

Everything in `DESIGN.md` marked "needs real hardware" or "waits for the Tiny" in one afternoon, in the order that
gets the most answers if the day is cut short. Written for the first target, a Lenovo ThinkCentre Tiny (Haswell class,
DESIGN.md 4.7); it applies to any box. Record every number with its date and the image digest; the probe prints both.

## Before the day (at the build host, 10 min + the ISO download)

1. **Build a test installer** with a login user, because the release image has no password and no shell. Never
   publish this ISO.
   ```
   IMAGE_REF=ghcr.io/zerconian/ottoman:stable TEST_USER=<you> TEST_SSH_KEY="$(cat ~/.ssh/<key>.pub)" \
     scripts/make-netinst-iso.sh build/tiny-test.iso
   ```
   The image is pulled from ghcr during the install, so the box needs wired network. (`DEV=1` dev images and the
   `INSECURE_REGISTRY` option are for the VM loop; the box should run the public `:stable`.)
2. **Write the stick** (replace `sdX` with the stick, check with `lsblk` first; this erases it):
   ```
   sudo dd if=build/tiny-test.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```
3. Pack: HDMI cable to a TV that supports CEC (not a monitor: the CEC and ELD checks need a TV), Ethernet cable, a USB
   keyboard as the fallback input, a phone on the same Wi-Fi as the box's wired LAN, any IR remote and USB IR receiver
   you own, a Pulse-Eight USB-CEC adapter if you have one (most PCs have no CEC on their HDMI port).

## On the day

Each step says what to record. The probe (`scripts/tiny-probe.sh`) does the measuring; the rest is eyes and a stopwatch.

| # | Step | Record |
|---|------|--------|
| 1 | Firmware: boot menu, confirm UEFI mode. Leave Secure Boot as found the first time. | Secure Boot state (the probe prints it); whether the stick booted with it on |
| 2 | Boot the stick. The menu auto-selects after 5 s; the install is unattended. Stopwatch from the menu to the reboot. | Install wall time; any anaconda prompt (there should be none); whether the box rebooted on its own |
| 3 | First boot: Language, Network, Setup installs the default apps, launcher. Stopwatch from the reboot to the launcher. | Time to first run; time to launcher with all tiles; anything that looked wrong on the TV (overscan, wrong resolution, no signal) |
| 4 | From the build host: `scripts/tiny-probe.sh <you>@<box-ip>` (the IP is on the first-run network screen and in Settings > Network). | The whole file lands in `build/probe/`. Key lines: `model` (the open Tiny CPU question), `vainfo i965` / `vainfo iHD` and their `h264 decode` lines, every `card*-HDMI*` connector line, the `eld#` line (the TV's audio formats), `IR receivers`, `CEC devices`, `Bluetooth adapters`, `systemd-analyze`, `mem-used` |
| 5 | Playback: sign Jellyfin in, play a 1080p H.264 file that direct-plays (check the server's dashboard says Direct Play). Run `scripts/tiny-probe.sh <you>@<box-ip> --sample 30` while it plays. Repeat with Plezy if installed. | `system cpu busy` and the per-process lines. Hardware decode on Haswell looks like well under 100 % of one core for the player; 200 % and up means software decode, and the `journal mentions` lines say which driver was tried. Also frame drops or tearing by eye |
| 6 | HDMI audio: Settings > Audio should list the HDMI sink; select it; play something. | Whether the sink appeared without a restart; whether sound came out; whether stereo only or the ELD's multichannel formats were offered |
| 7 | Display: Settings > Display, set the TV's native mode (1080p60 or 4K30 on HDMI 1.4), confirm, then let it idle 5 min for the screensaver and 30 for display off. | Mode list sanity; whether the TV reported "no signal" at display off and woke on a key |
| 8 | CEC: press the TV remote's arrows and OK with the launcher up. | Whether anything moved. With no `/dev/cec*` in the probe, nothing will; that decides whether a Pulse-Eight adapter is the plan (DESIGN.md 4.6) |
| 9 | IR: with a receiver plugged in, press a remote's keys; the probe's `evdev devices` list shows whether the kernel made it a keyboard. | Device name, which keys arrived (watch the shell: Up/Down move rows) |
| 10 | Bluetooth: the probe's `Bluetooth adapters` line. The image has no bluez yet, so pairing is not testable; this only decides whether to add it. | Adapter present or not |
| 11 | Phone remote: open `http://<box-ip>:18820/` on the phone. | Whether the page loads over Wi-Fi to wired; latency by feel |
| 12 | Updates: Settings > Updates > Check. | Result text; later, after a release, Apply and confirm the digest changed in the probe |
| 13 | Idle: after 30 min with nothing running, run the probe once more. | `mem-used`, thermal lines, `rapl package power` |

## Bringing it home

- Paste the probe files' key lines into `DESIGN.md` 4.7 (CPU, decode, audio, adapters) and the M1/M3 rows of 7, with
  the date and digest. Decisions that wait on the data: i965 vs iHD as the default driver, whether a CEC adapter is
  bought, whether bluez joins the image, whether Haswell stays the floor tier.
- Anything that did not work goes in as a dated `[D]` with what was seen, not a guess at the cause.

## If something goes wrong

- **No ssh:** the stick was built without `TEST_USER`, or the box got a different IP; the first-run network screen
  shows the address. A USB keyboard on the box reaches the launcher but there is no shell on the release image.
- **Black screen after the install:** hold Shift at power-on for the grub menu; pick the previous entry if there are
  two (bootc keeps the rollback). The greenboot watchdog rolls a failing boot back on its own after a few minutes.
- **Install stalls at pulling the image:** the netinstall needs wired network with DHCP; Wi-Fi is not configured until
  first run.
- **Stick does not boot with Secure Boot on:** turn it off for the day and record that; the image boots Fedora's
  signed shim and kernel, so this would be a finding, not an expectation.

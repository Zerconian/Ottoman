# Releases

Built by `scripts/release.sh` or the GitHub workflow: a DEV=0 image pushed to `ghcr.io/zerconian/ottoman:stable` and an
immutable `:<date>-<sha>` tag, plus the netinstall ISO attached to the GitHub Release. Installed boxes follow `:stable`.
The first row predates the move to GitHub (2026-11-04): it went to a private registry and an offline ISO that was never published.

| built (UTC) | tag | image digest | ISO | ISO sha256 (first 16) |
|---|---|---|---|---|
| 2026-11-03T23:48Z | 20261103-74d33d1 | ee03c3a2c2dc | ottoman-20261103-74d33d1.iso | d032661bbecf2176 |
| 2026-11-04T17:17Z | 20261104-47fce9b | 3fd632faefc5 | ottoman-20261104-47fce9b-netinstall.iso | 2e19e2e6b9b096a4 |
| 2026-11-04T18:16Z | 20261104-cd0f5bb | c9ebc12e1204 | ottoman-20261104-cd0f5bb-netinstall.iso | d8a7c94f10a60b06 | built by GitHub Actions, on the GitHub Release |
| 2026-11-04T21:29Z | 20261104-79c7d47 | 3e79450728d5 | ottoman-20261104-79c7d47-netinstall.iso | 7b2faa755c1ecedf | built by GitHub Actions (run 41915272427, 8 min), on the GitHub Release; Plezy opt-in tile, branded installer menu, box grub line |
| 2026-11-05T17:59Z | 20261105-323fc77 | f9d60d745170 | ottoman-20261105-323fc77-netinstall.iso | ab83bc7c4f2f9bc7 | built by GitHub Actions (run 42079848949, 8.6 min), on the GitHub Release; Plezy wrapper (TV layout after sign-in), Plezy telemetry blackholed, shell fullscreen guard |
| 2026-11-05T22:42Z | 20261105-911a92d | f355b4bb5f0e | ottoman-20261105-911a92d-netinstall.iso | f6eadd96b87aeca9 | built by GitHub Actions (run 42122648840, 7.6 min), on the GitHub Release; phone remote without an app (QR + ottoman.local, Android TV Remote v2 server on 6466/6467), portal Inhibit backend (Plezy wake lock holds the screensaver), Settings > Audio duplicate sink names, hardware-day kit. Update proven on the test VM: f9d60d745170 -> f355b4bb5f0e via bootc upgrade, portal backend and remote server up after the reboot |
| 2026-11-05T23:38Z | 20261105-368e153 | bb631e86f4dc | ottoman-20261105-368e153-netinstall.iso | d4a9eec35c10f9e6 | built by GitHub Actions (run 42129817682, 8.4 min), on the GitHub Release; phone remote taps fixed (the Android TV remote sends press/release, now a real key down/up in inputd, stuck-key release), LAN test scripts (vm-iso.sh LAN=1, vm-lan-publish.sh). First real phone (a Pixel) paired and drove the launcher on the test VM through the LAN rig |

# Releases

Built by `scripts/release.sh` or the GitHub workflow: a DEV=0 image pushed to `ghcr.io/zerconian/ottoman:stable` and an
immutable `:<date>-<sha>` tag, plus the netinstall ISO attached to the GitHub Release. Installed boxes follow `:stable`.
The first row predates the move to GitHub (2026-11-04): it went to a private registry and an offline ISO that was never published.

| built (UTC) | tag | image digest | ISO | ISO sha256 (first 16) |
|---|---|---|---|---|
| 2026-11-03T23:48Z | 20261103-74d33d1 | ee03c3a2c2dc | ottoman-20261103-74d33d1.iso | d032661bbecf2176 |

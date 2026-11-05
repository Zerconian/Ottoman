#!/bin/bash
# Hardware day probe (M1/M3 measurements that wait for a real box, DESIGN.md 4.7 and 7): one run collects what the
# design doc still has as "needs real hardware": CPU model and generation, which VA-API driver answers (i965 vs iHD),
# HDMI connectors and the TV's audio capabilities (ELD), PipeWire sinks, IR/CEC/Bluetooth adapters, USB devices,
# boot time, idle RAM, network link. `--sample N` adds an N second CPU/GPU sample while something plays.
#
# Usage, from the build host (the box needs a login user with passwordless sudo: a TEST_USER netinstall ISO, see
# docs/HARDWARE.md):      scripts/tiny-probe.sh user@box[:port] [--sample 30]  -> stdout + build/probe/<box>-<utc>.txt
#        on the box itself: sudo scripts/tiny-probe.sh --local [--sample 30]
# Every section prints a result or an explicit "n/a: <why>"; a missing tool never prints nothing (gate rule).
set -uo pipefail

if [ "${1:-}" != --local ]; then
  TARGET=${1:?usage: tiny-probe.sh user@box[:port] [--sample N] | --local [--sample N]}; shift
  PORT=22; case "$TARGET" in *:*) PORT=${TARGET##*:}; TARGET=${TARGET%:*};; esac
  cd "$(dirname "$0")/.."
  [ -f .ottoman-dev.env ] && . ./.ottoman-dev.env; . ./scripts/dev-env.sh
  mkdir -p build/probe
  OUT="build/probe/${TARGET##*@}${PORT:+-$PORT}-$(date -u +%Y%m%dT%H%M%SZ).txt"
  echo "probe: $TARGET -> $OUT"
  # the script travels on stdin; its arguments follow --local
  ssh -i "$DEV_SSH_IDENTITY" -p "$PORT" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="${PROBE_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}" -o ConnectTimeout=5 "$TARGET" \
      "sudo -n bash -s -- --local $*" < "$0" | tee "$OUT"
  echo "probe: saved $OUT ($(wc -l < "$OUT") lines)"
  exit "${PIPESTATUS[0]}"
fi
shift   # --local
SAMPLE=0; [ "${1:-}" = --sample ] && SAMPLE=${2:-30}
[ "$(id -u)" = 0 ] || { echo "tiny-probe: run as root (sudo)"; exit 2; }

sec() { printf '\n== %s\n' "$1"; }
kv() { printf '%-28s %s\n' "$1:" "$2"; }
have() { command -v "$1" >/dev/null 2>&1; }
na() { echo "n/a: $1"; }
first() { for f in "$@"; do [ -r "$f" ] && { cat "$f"; return; }; done; echo "?"; }

sec "identity ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
kv hostname "$(hostname)"
kv build-info "$(head -1 /usr/share/ottoman/build-info 2>/dev/null || echo '?')"
if have bootc; then
  bootc status --format json 2>/dev/null | python3 -c '
import json,sys
s=json.load(sys.stdin)["status"]; b=s["booted"]["image"]
print("%-28s %s %s" % ("image:", b["image"]["image"], b["imageDigest"][7:19]))
r=s.get("rollback"); print("%-28s %s" % ("rollback:", (r["image"]["imageDigest"][7:19] if r else "none")))' || na "bootc status failed"
else na "bootc not installed"; fi
kv kernel "$(uname -r)"
kv uptime "$(cut -d' ' -f1 /proc/uptime) s"
kv os "$(. /etc/os-release; echo "$PRETTY_NAME")"

sec "machine"
kv vendor "$(first /sys/class/dmi/id/sys_vendor)"
kv product "$(first /sys/class/dmi/id/product_name) / $(first /sys/class/dmi/id/product_version)"
kv board "$(first /sys/class/dmi/id/board_name)"
kv bios "$(first /sys/class/dmi/id/bios_version) ($(first /sys/class/dmi/id/bios_date))"
kv firmware "$([ -d /sys/firmware/efi ] && echo UEFI || echo BIOS)"
SB=$(od -An -tu1 /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | awk '{print ($5==1)?"enabled":"disabled"}'); kv secure-boot "${SB:-unknown (no SecureBoot efivar)}"

sec "cpu"
MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')
kv model "$MODEL"
kv family-model-stepping "$(grep -m1 'cpu family' /proc/cpuinfo | awk '{print $4}')/$(grep -m1 '^model' /proc/cpuinfo | awk '{print $3}')/$(grep -m1 stepping /proc/cpuinfo | awk '{print $3}')"
kv cores-threads "$(grep '^core id' /proc/cpuinfo | sort -u | wc -l) cores, $(nproc) threads"
kv max-freq "$(awk '{printf "%.2f GHz", $1/1e6}' /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo '?')"
kv governor "$(first /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
FLAGS=$(grep -m1 '^flags' /proc/cpuinfo)
for f in sse4_2 avx avx2 aes; do case " $FLAGS " in *" $f "*) kv "flag $f" yes;; *) kv "flag $f" NO;; esac; done
kv microcode "$(grep -m1 microcode /proc/cpuinfo | awk '{print $3}')"
kv virtualised "$(systemd-detect-virt 2>/dev/null || echo '?')"

sec "memory + disk"
kv mem-total "$(awk '/MemTotal/{printf "%d MB", $2/1024}' /proc/meminfo)"
kv mem-available "$(awk '/MemAvailable/{printf "%d MB", $2/1024}' /proc/meminfo)"
kv mem-used "$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d MB", (t-a)/1024}' /proc/meminfo)"
kv swap "$(awk '/SwapTotal/{printf "%d MB", $2/1024}' /proc/meminfo) ($(swapon --show=NAME,TYPE --noheadings 2>/dev/null | tr '\n' ' ' | sed 's/ *$//'))"
echo "top RSS:"; ps -eo rss,comm --sort=-rss | head -9 | tail -8 | awk '{printf "  %6d MB  %s\n", $1/1024, $2}'
echo "disks:"; lsblk -d -o NAME,SIZE,ROTA,TRAN,MODEL 2>/dev/null | sed 's/^/  /' || na "lsblk missing"
kv root-fs "$(df -h /sysroot 2>/dev/null | awk 'NR==2{print $2" total, "$4" free"}' || df -h / | awk 'NR==2{print $2" total, "$4" free"}')"

sec "boot"
kv systemd-analyze "$(systemd-analyze 2>/dev/null | head -1 || echo '?')"
BL=$(systemd-analyze blame --no-pager 2>/dev/null | head -6); echo "blame top 6:"; if [ -n "$BL" ]; then echo "$BL" | sed 's/^/  /'; else na "blame unavailable"; fi
kv greenboot "$(systemctl is-active greenboot-success.target 2>/dev/null) ($(systemctl show greenboot-healthcheck.service -p ExecMainStatus --value 2>/dev/null) = healthcheck exit)"
kv session "$(systemctl is-active ottoman-session.service) / restarts $(systemctl show ottoman-session.service -p NRestarts --value)"
kv inputd "$(systemctl is-active ottoman-inputd.service) / restarts $(systemctl show ottoman-inputd.service -p NRestarts --value)"
kv journal-errors-this-boot "$(journalctl -b -p err --no-pager -q 2>/dev/null | wc -l) lines"
journalctl -b -p err --no-pager -q -o cat 2>/dev/null | sort | uniq -c | sort -rn | head -5 | sed 's/^/  /'

sec "graphics"
for c in /sys/class/drm/card[0-9]; do
  [ -e "$c/device" ] || continue
  kv "$(basename "$c") driver" "$(basename "$(readlink -f "$c/device/driver" 2>/dev/null)" 2>/dev/null) pci $(first "$c/device/vendor"):$(first "$c/device/device") (subsystem $(first "$c/device/subsystem_device"))"
done
kv render-nodes "$(ls /dev/dri/ 2>/dev/null | tr '\n' ' ')"
for c in /sys/class/drm/card*-*; do
  [ -e "$c/status" ] || continue
  st=$(cat "$c/status"); en=$(cat "$c/enabled" 2>/dev/null)
  modes=$(head -3 "$c/modes" 2>/dev/null | tr '\n' ' ')
  edid=$(stat -c %s "$c/edid" 2>/dev/null)
  kv "$(basename "$c")" "$st, $en, edid ${edid:-0} B, modes: ${modes:-none}"
done
kv gpu-freq "cur $(first /sys/class/drm/card*/gt_cur_freq_mhz | head -1) / max $(first /sys/class/drm/card*/gt_max_freq_mhz | head -1) MHz (i915 only)"
if have vainfo; then
  for drv in i965 iHD; do
    out=$(LIBVA_DRIVER_NAME=$drv timeout 20 vainfo --display drm --device /dev/dri/renderD128 2>&1)
    rc=$?
    ver=$(echo "$out" | grep -m1 -E 'Driver version|vainfo: Driver' | sed 's/.*: *//')
    if [ $rc = 0 ] && [ -n "$ver" ]; then
      kv "vainfo $drv" "OK: $ver"
      for p in VAProfileH264High VAProfileHEVCMain VAProfileHEVCMain10 VAProfileVP9Profile0 VAProfileAV1Profile0 VAProfileJPEGBaseline; do
        ep=$(echo "$out" | grep -E "^\s*$p\s*:" | sed "s/.*: *//" | sort -u | tr '\n' ' ')
        [ -n "$ep" ] && kv "  $p" "$ep"
      done
      echo "$out" | grep -q 'VAProfileH264High.*VAEntrypointVLD' && kv "  h264 decode" yes || kv "  h264 decode" NO
      echo "$out" | grep -q 'VAProfileHEVCMain .*VAEntrypointVLD' && kv "  hevc decode" yes || kv "  hevc decode" NO
    else
      why=$(echo "$out" | grep -i -E 'error|fail|not found|cannot' | tail -1); [ -z "$why" ] && why=$(echo "$out" | grep -v '^$' | tail -1)
      kv "vainfo $drv" "FAILED (rc $rc): $(echo "$why" | cut -c1-120)"
    fi
  done
else na "vainfo missing (libva-utils not in the image)"; fi

sec "audio"
if [ -r /proc/asound/cards ]; then
  grep -E '^ *[0-9]' /proc/asound/cards | sed 's/^/  /'
  for eld in /proc/asound/card*/eld#*; do
    [ -r "$eld" ] || continue
    if grep -q 'monitor_present\s*1' "$eld"; then
      kv "$(basename "$(dirname "$eld")")/$(basename "$eld")" "present: $(grep -m1 monitor_name "$eld" | cut -d'	' -f2-) | sad: $(grep -c '^sad' "$eld") formats: $(grep -E '^sad[0-9]+_coding_type' "$eld" | sed 's/.*\] //' | tr '\n' ',' | sed 's/,$//')"
    else kv "$(basename "$(dirname "$eld")")/$(basename "$eld")" "no monitor"; fi
  done
else na "/proc/asound missing (no sound cards or no ALSA)"; fi
U=$(id -u ottoman 2>/dev/null)
if [ -n "$U" ] && have wpctl; then
  echo "pipewire sinks (ottoman session):"
  WP=$(runuser -u ottoman -- env XDG_RUNTIME_DIR=/run/user/$U wpctl status 2>&1 | awk '/^Audio/{a=1} /^Video/{a=0} a && /Sinks:/{s=1; next} a && /Sources:/{s=0} a && s' | grep -E '[0-9]+\.' | sed 's/^[ │├─└]*/  /')
  if [ -n "$WP" ]; then echo "$WP"; else echo "  none (headless, or wpctl failed)"; fi
else na "wpctl or ottoman user missing"; fi

sec "remotes and input"
if [ -d /sys/class/rc ] && [ -n "$(ls /sys/class/rc 2>/dev/null)" ]; then
  for r in /sys/class/rc/rc*; do kv "IR $(basename "$r")" "$(first "$r/device/name" 2>/dev/null | head -1) protocols: $(first "$r/protocols")"; done
else kv "IR receivers" "none (/sys/class/rc empty)"; fi
kv "CEC devices" "$(ls /dev/cec* 2>/dev/null | tr '\n' ' ')${CEC:-}$( ls /dev/cec* >/dev/null 2>&1 || echo 'none (/dev/cec*)')"
if [ -d /sys/class/bluetooth ] && [ -n "$(ls /sys/class/bluetooth 2>/dev/null)" ]; then
  for h in /sys/class/bluetooth/hci*; do kv "BT $(basename "$h")" "$(first "$h/address") $(have bluetoothctl && echo '(bluez present)' || echo '(bluez NOT in image)')"; done
else kv "Bluetooth adapters" "none (/sys/class/bluetooth empty)"; fi
echo "usb devices:"
for d in /sys/bus/usb/devices/[0-9]*-[0-9]*; do
  [ -r "$d/idVendor" ] || continue; case "$d" in *:*) continue;; esac
  printf '  %s:%s  %s %s\n' "$(cat "$d/idVendor")" "$(cat "$d/idProduct")" "$(first "$d/manufacturer")" "$(first "$d/product")"
done
echo "evdev devices:"
python3 - <<'PY' 2>&1 | sed 's/^/  /'
try:
    from evdev import InputDevice, list_devices, ecodes as e
    for p in sorted(list_devices()):
        d = InputDevice(p); caps = d.capabilities()
        keys = set(caps.get(e.EV_KEY, []))
        kind = []
        if e.BTN_SOUTH in keys or e.BTN_DPAD_UP in keys: kind.append("gamepad")
        if e.KEY_HOMEPAGE in keys or e.KEY_BACK in keys: kind.append("remote-like")
        if e.KEY_A in keys and e.KEY_Z in keys: kind.append("keyboard")
        if e.BTN_LEFT in keys: kind.append("mouse")
        print(f"{p}: {d.name} [{', '.join(kind) or 'other'}] {len(keys)} keys")
except Exception as ex:
    print("n/a:", ex)
PY

sec "network"
if have nmcli; then nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev status 2>/dev/null | sed 's/^/  /'; else na "nmcli missing"; fi
for n in /sys/class/net/*; do
  i=$(basename "$n"); [ "$i" = lo ] && continue
  kv "$i" "$(first "$n/operstate") speed $(first "$n/speed") Mb/s driver $(basename "$(readlink -f "$n/device/driver" 2>/dev/null)" 2>/dev/null) mac $(cut -c1-8 "$n/address")..."
done
kv "wifi adapters" "$(ls -d /sys/class/net/*/wireless 2>/dev/null | wc -l)"
kv "dns resolves ghcr.io" "$(getent ahosts ghcr.io >/dev/null 2>&1 && echo yes || echo NO)"

sec "thermal + power"
for t in /sys/class/thermal/thermal_zone*; do [ -r "$t/temp" ] && kv "$(first "$t/type")" "$(awk '{printf "%.0f C", $1/1000}' "$t/temp")"; done
kv "rapl package power" "$(d=/sys/class/powercap/intel-rapl:0; [ -r $d/energy_uj ] && { a=$(cat $d/energy_uj); sleep 1; b=$(cat $d/energy_uj); echo "$(( (b-a)/1000000 )) W (1 s)"; } || echo 'n/a')"

if [ "$SAMPLE" -gt 0 ]; then
  sec "playback sample ($SAMPLE s): start playing something NOW"
  python3 - "$SAMPLE" <<'PY'
import sys, time, os, glob
N = int(sys.argv[1]); procs = {}
def cpu_total():
    f = open("/proc/stat").readline().split(); v = list(map(int, f[1:])); return sum(v), v[3] + v[4]
def media():
    out = {}
    for p in glob.glob("/proc/[0-9]*"):
        try:
            comm = open(p + "/comm").read().strip()
            if any(k in comm.lower() for k in ("jellyfin", "plezy", "mpv", "firefox", "vacuum", "electron", "kodi", "retroarch", "moonlight", "ottoman-shell", "sway")):
                st = open(p + "/stat").read().split(")")[-1].split(); out[(int(p[6:]), comm)] = int(st[11]) + int(st[12])
        except Exception: pass
    return out
def gpu():
    for f in glob.glob("/sys/class/drm/card*/gt_cur_freq_mhz"):
        try: return int(open(f).read())
        except Exception: pass
    return None
t0, i0 = cpu_total(); m0 = media(); g = []; hz = os.sysconf("SC_CLK_TCK")
for _ in range(N): time.sleep(1); v = gpu(); g.append(v) if v is not None else None
t1, i1 = cpu_total(); m1 = media()
print("%-28s %.0f %% of all cores (%.0f %% of one core)" % ("system cpu busy:", 100 * (1 - (i1 - i0) / (t1 - t0)), 100 * (1 - (i1 - i0) / (t1 - t0)) * os.cpu_count()))
for k in sorted(set(m0) | set(m1), key=lambda k: -(m1.get(k, 0) - m0.get(k, 0))):
    d = (m1.get(k, 0) - m0.get(k, 0)) / hz / N * 100
    if d >= 1: print("%-28s %.0f %% of one core" % (f"  {k[1]}[{k[0]}]:", d))
if g: print("%-28s min %d / avg %d / max %d MHz" % ("gpu freq (i915):", min(g), sum(g) // len(g), max(g)))
else: print("%-28s n/a" % "gpu freq:")
PY
  echo "journal mentions of va/hw decode in the last $((SAMPLE+30)) s:"
  journalctl --since "-$((SAMPLE+30))s" --no-pager -q -o cat 2>/dev/null | grep -i -E 'vaapi|va-api|libva|hwdec|hardware decod|i965|iHD' | sort | uniq -c | sort -rn | head -6 | sed 's/^/  /'
fi
printf '\n== end\n'

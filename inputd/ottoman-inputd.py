#!/usr/bin/python3
"""ottoman-inputd (M3, DESIGN.md 4.6): one daemon turns every remote into the keys the shell already
handles. Sources: the phone web remote (HTTP on :18820), gamepads/remotes on evdev (BTN_*/ABS_HAT* ->
keys). IR remotes already arrive as keyboards through the kernel rc layer. CEC comes with hardware (M3.x).
Sink: a uinput virtual keyboard. Runs as a system service (uinput + /dev/input need root). stdlib + python3-evdev."""
import http.server, json, os, select, sys, threading, time, urllib.parse
from evdev import InputDevice, UInput, ecodes as e, list_devices

PORT = int(os.environ.get("OTTOMAN_REMOTE_PORT", "18820"))
KEYS = {  # name used by the phone page and the gamepad map -> uinput key
    "up": e.KEY_UP, "down": e.KEY_DOWN, "left": e.KEY_LEFT, "right": e.KEY_RIGHT,
    "ok": e.KEY_ENTER, "back": e.KEY_ESC, "home": e.KEY_HOME, "menu": e.KEY_F2,
    "play": e.KEY_PLAYPAUSE, "volup": e.KEY_VOLUMEUP, "voldown": e.KEY_VOLUMEDOWN, "mute": e.KEY_MUTE,
}
GAMEPAD = {  # evdev button -> key name
    e.BTN_SOUTH: "ok", e.BTN_EAST: "back", e.BTN_MODE: "home", e.BTN_START: "menu", e.BTN_SELECT: "menu",
    e.BTN_NORTH: "play", e.BTN_DPAD_UP: "up", e.BTN_DPAD_DOWN: "down", e.BTN_DPAD_LEFT: "left", e.BTN_DPAD_RIGHT: "right",
}
HAT = {(e.ABS_HAT0X, -1): "left", (e.ABS_HAT0X, 1): "right", (e.ABS_HAT0Y, -1): "up", (e.ABS_HAT0Y, 1): "down"}

ui = UInput({e.EV_KEY: sorted(set(KEYS.values()))}, name="Ottoman remote", version=1)
# Pointer mode (M4.1): web players are built for a mouse. A long press on Menu (or the phone page's Pointer button)
# flips the D-pad into moving a virtual mouse and OK into a click; Back/Home/Menu leave it. Separate uinput mouse.
mouse = UInput({e.EV_KEY: [e.BTN_LEFT, e.BTN_RIGHT], e.EV_REL: [e.REL_X, e.REL_Y, e.REL_WHEEL]}, name="Ottoman pointer", version=1)
lock = threading.Lock()
pointer = {"on": False, "step": 18}
POINTER_MOVES = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}

def pointer_set(on):
    pointer["on"] = bool(on); log("pointer mode " + ("on" if pointer["on"] else "off"))

def pointer_key(name, hold_ms=0):
    """Handle a key while pointer mode is on. Returns True if consumed."""
    if name in POINTER_MOVES:
        dx, dy = POINTER_MOVES[name]; n = 3 if hold_ms else 1
        with lock:
            for _ in range(n): mouse.write(e.EV_REL, e.REL_X, dx * pointer["step"]); mouse.write(e.EV_REL, e.REL_Y, dy * pointer["step"]); mouse.syn()
        return True
    if name == "ok":
        with lock: mouse.write(e.EV_KEY, e.BTN_LEFT, 1); mouse.syn(); time.sleep(0.05); mouse.write(e.EV_KEY, e.BTN_LEFT, 0); mouse.syn()
        return True
    if name in ("back", "home", "menu"):
        pointer_set(False); return name == "menu"      # Back/Home still reach the system after leaving pointer mode
    return False

def log(msg): print("inputd:", msg, flush=True)

def press(name, hold_ms=0):
    if name == "pointer": pointer_set(not pointer["on"]); return True
    if name == "menu" and hold_ms >= 500: pointer_set(not pointer["on"]); return True
    if pointer["on"] and pointer_key(name, hold_ms): return True
    code = KEYS.get(name)
    if code is None: return False
    with lock:
        ui.write(e.EV_KEY, code, 1); ui.syn()
        if hold_ms: time.sleep(min(hold_ms, 3000) / 1000)
        ui.write(e.EV_KEY, code, 0); ui.syn()
    return True

PAGE = """<!doctype html><html><head><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1,user-scalable=no">
<title>Ottoman remote</title><style>
:root{color-scheme:dark}body{margin:0;background:#101214;color:#e6e7ea;font:18px system-ui;-webkit-user-select:none;user-select:none}
h1{font-weight:400;letter-spacing:.3em;font-size:14px;color:#8a8f98;text-align:center;margin:18px 0 6px}
.pad{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;max-width:420px;margin:0 auto;padding:12px}
button{background:#1c2026;color:#e6e7ea;border:1px solid #3a3f47;border-radius:12px;font-size:22px;padding:22px 0;touch-action:manipulation}
button:active{background:#ffffff;color:#111}.ok{background:#2a2f38}.wide{grid-column:span 3}.half{grid-column:span 1}
</style></head><body><h1>OTTOMAN</h1><div class=pad>
<button data-k=menu>Menu</button><button data-k=up>&#9650;</button><button data-k=home>Home</button>
<button data-k=left>&#9664;</button><button class=ok data-k=ok>OK</button><button data-k=right>&#9654;</button>
<button data-k=back>Back</button><button data-k=down>&#9660;</button><button data-k=play>&#9654;&#10074;&#10074;</button>
<button data-k=voldown>Vol &minus;</button><button data-k=mute>Mute</button><button data-k=volup>Vol +</button>
<button class=wide data-k=pointer>Pointer mode (D-pad moves the mouse, OK clicks)</button>
</div><script>
let t;for(const b of document.querySelectorAll('button')){
 const send=(hold)=>fetch('/key?name='+b.dataset.k+(hold?'&hold=800':''),{method:'POST'});
 b.addEventListener('pointerdown',ev=>{ev.preventDefault();b.held=false;t=setTimeout(()=>{b.held=true;send(true)},600)});
 b.addEventListener('pointerup',ev=>{ev.preventDefault();clearTimeout(t);if(!b.held)send(false)});
 b.addEventListener('pointerleave',()=>clearTimeout(t));}
</script></body></html>"""

def sway(cmd):
    """Run a sway command in the TV session (the daemon is root; the session belongs to the ottoman user)."""
    import glob, subprocess
    socks = glob.glob("/run/user/*/sway-ipc.*.sock")
    if not socks: return False
    import pwd, os
    user = pwd.getpwuid(os.stat(socks[0]).st_uid).pw_name
    r = subprocess.run(["runuser", "-u", user, "--", "env", f"SWAYSOCK={socks[0]}", "swaymsg", cmd], capture_output=True, text=True, timeout=5)
    return r.returncode == 0

def power(state):
    """Home Assistant "power": the box never suspends (DESIGN.md 4.10 #7); off = display off + playback paused, on = display on."""
    if state == "off": ok = sway("output * power off"); log("power off (display)"); return ok
    if state == "on": ok = sway("output * power on"); press("home"); log("power on (display + home)"); return ok
    return False

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        if self.path in ("/", "/index.html"):
            body = PAGE.encode(); self.send_response(200); self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
        elif self.path == "/status":
            body = json.dumps({"pointer": pointer["on"], "keys": sorted(KEYS), "power": ["on", "off"]}).encode(); self.send_response(200); self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
        elif self.path == "/keys":
            body = json.dumps(sorted(KEYS)).encode(); self.send_response(200); self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
        else: self.send_error(404)
    def do_POST(self):
        u = urllib.parse.urlparse(self.path); q = urllib.parse.parse_qs(u.query)
        if u.path == "/power" and power(q.get("state", [""])[0]):
            self.send_response(204); self.end_headers(); return
        if u.path == "/key" and press(q.get("name", [""])[0], int(q.get("hold", ["0"])[0] or 0)):
            log(f"key {q['name'][0]} from {self.client_address[0]}" + (" (hold)" if q.get("hold") else "") + (" [pointer]" if pointer["on"] else ""))
            self.send_response(204); self.end_headers()
        else: self.send_error(400)

def gamepads():
    """Watch evdev devices that look like gamepads/remotes (have BTN_SOUTH or BTN_DPAD_*), map to keys."""
    seen = {}
    while True:
        for path in list_devices():
            if path in seen: continue
            try:
                d = InputDevice(path); caps = d.capabilities()
                keys = set(caps.get(e.EV_KEY, []))
                if d.name == "Ottoman remote" or not (keys & {e.BTN_SOUTH, e.BTN_DPAD_UP, e.BTN_MODE}): d.close(); continue
                seen[path] = d; log(f"gamepad: {d.name} at {path}")
                threading.Thread(target=pump, args=(path, d), daemon=True).start()
            except Exception as ex: log(f"evdev open {path}: {ex}")
        time.sleep(3)

def pump(path, d):
    try:
        for ev in d.read_loop():
            if ev.type == e.EV_KEY and ev.value == 1 and ev.code in GAMEPAD: press(GAMEPAD[ev.code]); log(f"gamepad {d.name}: {GAMEPAD[ev.code]}")
            elif ev.type == e.EV_KEY and ev.value == 1 and ev.code == e.BTN_THUMBR: press("pointer")
            elif ev.type == e.EV_ABS and (ev.code, ev.value) in HAT: press(HAT[(ev.code, ev.value)]); log(f"gamepad {d.name}: {HAT[(ev.code, ev.value)]}")
    except OSError as ex: log(f"gamepad {d.name} gone: {ex}")

if __name__ == "__main__":
    threading.Thread(target=gamepads, daemon=True).start()
    srv = http.server.ThreadingHTTPServer(("", PORT), H)   # fails loudly if :18820 is taken (project rule)
    log(f"phone remote on :{PORT}, uinput keyboard ready")
    srv.serve_forever()

: "${XVSR_OUTPUT:=DP-2}"
: "${XVSR_IN:=1920x1080}"
: "${XVSR_OUT:=}"
: "${XVSR_QUALITY:=STREAMING_ULTRA}"
: "${XVSR_FPS:=60}"
: "${XVSR_FILTER_PY:?}"
: "${XVSR_PYTHON:?}"
: "${XVSR_LIBS:=}"
: "${XVSR_GAME:=Grand Theft Auto VI}"
: "${XVSR_DISCORD_ID:=}"
export XVSR_GAME XVSR_DISCORD_ID

venv="${XDG_DATA_HOME:-$HOME/.local/share}/xvsr/venv"
state="${XDG_RUNTIME_DIR:-/tmp}/xvsr"
log="$state/xvsr.log"
conf="${XDG_CONFIG_HOME:-$HOME/.config}/xvsr"
rpc_py="$state/xvsr-rpc.py"
mkdir -p "$state"

msg() { echo "xvsr: $*" >&2; }

die() {
  msg "$*"
  if [ ! -t 2 ] && [ -n "${SWAYSOCK:-}" ]; then
    swaynag -t warning -m "xvsr: $*" >/dev/null 2>&1 &
  fi
  exit 1
}

have_venv() {
  [ -x "$venv/bin/python" ] && [ "$(cat "$venv/.xvsr-python" 2>/dev/null)" = "$XVSR_PYTHON" ]
}

filter() {
  have_venv || die "run 'xvsr setup' first"
  LD_LIBRARY_PATH="/run/opengl-driver/lib${XVSR_LIBS:+:$XVSR_LIBS}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    exec "$venv/bin/python" -u "$XVSR_FILTER_PY" "$@"
}

output_res() {
  swaymsg -t get_outputs -r | jq -r --arg o "$1" \
    '.[] | select(.name == $o) | "\((.rect.width * .scale) | round)x\((.rect.height * .scale) | round)"'
}

target_res() {
  if [ -n "$XVSR_OUT" ]; then
    echo "$XVSR_OUT"
    return
  fi
  local res
  res=$(output_res "$XVSR_OUTPUT")
  [ -n "$res" ] || die "can't find output $XVSR_OUTPUT"
  echo "$res"
}

show() {
  mpv - --no-config --title=xvsr --wayland-app-id=xvsr \
    --demuxer=rawvideo --demuxer-rawvideo-w="${1%x*}" --demuxer-rawvideo-h="${1#*x}" \
    --demuxer-rawvideo-mp-format=rgb24 --demuxer-rawvideo-fps="$XVSR_FPS" \
    --untimed --cache=no --demuxer-readahead-secs=0 --video-latency-hacks=yes \
    --no-audio --osc=no --osd-level=0 --cursor-autohide=always --keep-open=no \
    --really-quiet "${@:2}"
}

running() {
  [ -f "$state/pid" ] && kill -0 "$(cat "$state/pid")" 2>/dev/null
}

headless() {
  swaymsg -t get_outputs -r | jq -r 'first(.[] | select(.name | startswith("HEADLESS-")) | .name) // empty'
}

put_back() {
  [ -f "$state/win" ] || return 0
  local win ws out hl pos
  win=$(cat "$state/win")
  ws=$(cat "$state/ws")
  out=$(cat "$state/out")
  hl=$(cat "$state/headless")
  pos=$(cat "$state/pos" 2>/dev/null || true)
  rm -f "$state/win" "$state/ws" "$state/out" "$state/headless" "$state/pos"

  [ -n "$pos" ] && swaymsg -q "output $XVSR_OUTPUT position $pos" || true
  swaymsg -q "focus output $out" || true
  swaymsg -q "[con_id=$win] fullscreen disable" || true
  swaymsg -q "[con_id=$win] move container to workspace \"$ws\"" || true
  swaymsg -q "workspace \"$ws\"" || true
  swaymsg -q "[con_id=$win] focus" || true
  swaymsg -q "output $hl unplug" || true
  swaymsg -q "seat seat0 hide_cursor 0" || true
}

setup() {
  msg "setting up $venv, this downloads a few GB"
  mkdir -p "$(dirname "$venv")"
  "$XVSR_PYTHON" -m venv --clear "$venv"
  "$venv/bin/pip" install --upgrade pip
  "$venv/bin/pip" install --extra-index-url https://pypi.nvidia.com nvidia-vfx torch numpy
  echo "$XVSR_PYTHON" >"$venv/.xvsr-python"
  local res
  res=$(target_res 2>/dev/null || echo 2560x1440)
  (filter --selftest --in "$XVSR_IN" --out "$res" --quality "$XVSR_QUALITY")
  msg "done"
}

start() {
  running && die "already running"
  [ -n "${SWAYSOCK:-}" ] || die "not in sway"
  have_venv || die "run 'xvsr setup' first"

  local win ws out res hl
  win=$(swaymsg -t get_tree -r | jq -r 'first(.. | objects | select(.focused == true and (.type == "con" or .type == "floating_con")) | .id) // empty')
  [ -n "$win" ] || die "no window focused"
  ws=$(swaymsg -t get_workspaces -r | jq -r '.[] | select(.focused) | .name')
  out=$(swaymsg -t get_workspaces -r | jq -r '.[] | select(.focused) | .output')
  res=$(target_res)

  local rect x y h hx hy
  rect=$(swaymsg -t get_outputs -r | jq -r --arg o "$XVSR_OUTPUT" '.[] | select(.name == $o) | "\(.rect.x) \(.rect.y) \(.rect.height)"')
  [ -n "$rect" ] || die "can't find output $XVSR_OUTPUT"
  read -r x y h <<<"$rect"
  hx=$x
  hy=$((y + (h - ${XVSR_IN#*x}) / 2))
  [ "$hy" -ge "$y" ] || hy=$y

  hl=$(headless)
  if [ -z "$hl" ]; then
    swaymsg -q create_output
    hl=$(headless)
  fi
  [ -n "$hl" ] || die "couldn't create headless output"
  echo "$x $y" >"$state/pos"
  swaymsg -q "output $XVSR_OUTPUT position 20000 0"
  swaymsg -q "output $hl mode --custom ${XVSR_IN}@${XVSR_FPS}Hz position $hx $hy scale 1 enable"

  echo "$win" >"$state/win"
  echo "$ws" >"$state/ws"
  echo "$out" >"$state/out"
  echo "$hl" >"$state/headless"

  swaymsg -q "[con_id=$win] fullscreen disable"
  swaymsg -q "[con_id=$win] move container to output $hl"
  swaymsg -q "[con_id=$win] focus"
  swaymsg -q "[con_id=$win] fullscreen enable"
  swaymsg -q "focus output $XVSR_OUTPUT"

  : >"$log"
  set -m
  (
    msg "$(date +%T) $hl $XVSR_IN -> $XVSR_OUTPUT $res $XVSR_QUALITY"
    rpc_pid=
    if rpc_on; then
      write_rpc
      "$XVSR_PYTHON" -u "$rpc_py" &
      rpc_pid=$!
    fi
    wf-recorder -o "$hl" -c rawvideo -x bgr0 -m rawvideo -f pipe:1 |
      (filter --in "$XVSR_IN" --in-fmt bgr0 --out "$res" --quality "$XVSR_QUALITY" --stats 10) |
      show "$res" --fs --fs-screen-name="$XVSR_OUTPUT"
    msg "$(date +%T) stopped"
    [ -z "$rpc_pid" ] || kill "$rpc_pid" 2>/dev/null || true
    rm -f "$state/pid"
    put_back
  ) </dev/null >>"$log" 2>&1 &
  echo "$!" >"$state/pid"
  set +m

  for _ in $(seq 50); do
    if swaymsg -q '[app_id="^xvsr$"] move container to output '"$XVSR_OUTPUT"', fullscreen enable' 2>/dev/null; then
      break
    fi
    running || break
    sleep 0.1
  done
  swaymsg -q "[con_id=$win] focus" || true
  swaymsg -q "seat seat0 hide_cursor 1500" || true

  running || die "pipeline died, check $log"
  msg "started"
}

stop() {
  if running; then
    local pid
    pid=$(cat "$state/pid")
    kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  fi
  rm -f "$state/pid"
  put_back
}

ab() {
  running || die "not running"
  pkill -USR1 -f -- "$XVSR_FILTER_PY" || die "filter isn't running"
}

test_file() {
  local file=${1:?usage: xvsr test FILE}
  local res
  res=$(XVSR_OUT=${XVSR_OUT:-2560x1440} target_res)
  msg "$file at $XVSR_IN -> $res, $XVSR_QUALITY (q to quit)"
  echo "$$" >"$state/pid"
  ffmpeg -nostdin -hide_banner -loglevel error -re -i "$file" -an \
    -vf "scale=${XVSR_IN%x*}:${XVSR_IN#*x}:flags=bicubic" \
    -f rawvideo -pix_fmt rgb24 pipe:1 |
    (filter --in "$XVSR_IN" --in-fmt rgb24 --out "$res" --quality "$XVSR_QUALITY" --stats 5) |
    show "$res" || true
  rm -f "$state/pid"
}

write_rpc() {
  cat >"$rpc_py" <<'PY'
import json
import os
import signal
import socket
import struct
import sys
import time
import urllib.request
import uuid

HANDSHAKE, FRAME, CLOSE, PING, PONG = 0, 1, 2, 3, 4
LIST_URL = "https://discord.com/api/v9/applications/detectable"
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "xvsr", "detectable.json")
RUN = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
GAME_FILE = os.path.join(RUN, "xvsr", "game")
ROMAN = {"1": "i", "2": "ii", "3": "iii", "4": "iv", "5": "v", "6": "vi", "7": "vii", "8": "viii", "9": "ix", "10": "x"}


class Reload(Exception):
    pass


def log(*args):
    print("xvsr-rpc:", *args, file=sys.stderr, flush=True)


def games():
    try:
        fresh = time.time() - os.path.getmtime(CACHE) < 7 * 86400
    except OSError:
        fresh = False
    if not fresh:
        try:
            req = urllib.request.Request(LIST_URL, headers={"User-Agent": "xvsr"})
            data = urllib.request.urlopen(req, timeout=15).read()
            json.loads(data)
            os.makedirs(os.path.dirname(CACHE), exist_ok=True)
            with open(CACHE + ".tmp", "wb") as f:
                f.write(data)
            os.replace(CACHE + ".tmp", CACHE)
        except (OSError, ValueError) as e:
            log("couldn't download the game list:", e)
    try:
        with open(CACHE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return []


def norm(s):
    words = s.lower().replace(":", " ").replace("-", " ").split()
    s = " ".join(ROMAN.get(w, w) for w in words)
    if s == "gta" or s.startswith("gta "):
        s = "grand theft auto" + s[3:]
    return s


def find(query, limit=5):
    q = norm(query)
    hits = []
    for g in games():
        names = [norm(n) for n in [g.get("name")] + list(g.get("aliases") or []) if n]
        if q in names:
            rank = 0
        elif any(n.startswith(q) for n in names):
            rank = 1
        elif any(q in n for n in names):
            rank = 2
        else:
            continue
        hits.append((rank, len(g["name"]), g["id"], g["name"]))
    hits.sort()
    return [(i, name) for _, _, i, name in hits[:limit]]


def current():
    if os.environ.get("XVSR_DISCORD_ID"):
        return os.environ["XVSR_DISCORD_ID"], None
    try:
        with open(GAME_FILE) as f:
            i, name = f.read().rstrip("\n").split("\t", 1)
        return i, name
    except (OSError, ValueError):
        pass
    q = os.environ.get("XVSR_GAME", "")
    if q.isdigit():
        return q, None
    hits = find(q) if q else []
    if not hits:
        log(f"no discord game matches {q!r}")
        return None, None
    return hits[0]


def sockets():
    for d in (RUN, f"{RUN}/app/com.discordapp.Discord", f"{RUN}/.flatpak/dev.vencord.Vesktop/xdg-run",
              f"{RUN}/snap.discord", "/tmp"):
        for i in range(10):
            yield f"{d}/discord-ipc-{i}"


def send(s, op, data):
    body = json.dumps(data).encode()
    s.sendall(struct.pack("<II", op, len(body)) + body)


def recv_exact(s, n):
    buf = b""
    while len(buf) < n:
        chunk = s.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("discord closed the socket")
        buf += chunk
    return buf


def recv(s):
    op, n = struct.unpack("<II", recv_exact(s, 8))
    return op, json.loads(recv_exact(s, n))


def connect(client_id):
    for path in sockets():
        if not os.path.exists(path):
            continue
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            s.connect(path)
            send(s, HANDSHAKE, {"v": 1, "client_id": client_id})
            op, data = recv(s)
            if op == FRAME and data.get("evt") == "READY":
                return s
            s.close()
        except OSError:
            s.close()
    return None


def activity(start):
    a = {"type": 0, "timestamps": {"start": start}}
    for key, env in (("details", "XVSR_RPC_DETAILS"), ("state", "XVSR_RPC_STATE")):
        if os.environ.get(env):
            a[key] = os.environ[env]
    return a


def set_activity(s, act):
    send(s, FRAME, {"cmd": "SET_ACTIVITY", "args": {"pid": os.getpid(), "activity": act},
                    "nonce": str(uuid.uuid4())})


def close(s):
    try:
        set_activity(s, None)
        send(s, CLOSE, {})
    except OSError:
        pass
    s.close()


def main():
    if sys.argv[1:2] == ["--find"]:
        hits = find(" ".join(sys.argv[2:]))
        for i, name in hits:
            print(f"{i}\t{name}")
        sys.exit(0 if hits else 1)

    s = None

    def quit(*_):
        sys.exit(0)

    def reload(*_):
        raise Reload

    signal.signal(signal.SIGTERM, quit)
    signal.signal(signal.SIGINT, quit)
    signal.signal(signal.SIGHUP, reload)

    delay = 0
    while True:
        try:
            time.sleep(delay)
            delay = 5
            client_id, name = current()
            if not client_id:
                delay = 3600
                continue
            start = int(time.time())
            s = connect(client_id)
            if not s:
                delay = 15
                continue
            log(f"showing {name or client_id}")
            set_activity(s, activity(start))
            while True:
                op, data = recv(s)
                if op == PING:
                    send(s, PONG, data)
                elif op == CLOSE:
                    break
                elif data.get("evt") == "ERROR":
                    log(data.get("data", {}).get("message"))
        except Reload:
            log("switching game")
            delay = 0
        except (OSError, ConnectionError, struct.error, ValueError):
            pass
        finally:
            if s:
                close(s)
                s = None


if __name__ == "__main__":
    main()
PY
}

rpc_on() {
  [ ! -f "$conf/rpc-off" ]
}

game() {
  if [ $# -eq 0 ]; then
    if [ -f "$state/game" ]; then cut -f2 "$state/game"; else echo "$XVSR_GAME"; fi
    return
  fi
  local hit
  write_rpc
  hit=$("$XVSR_PYTHON" "$rpc_py" --find "$*" | head -n 1) || die "no discord game matches '$*'"
  printf '%s\n' "$hit" >"$state/game"
  pkill -HUP -f -- "$rpc_py" || true
  msg "discord game: $(cut -f2 <<<"$hit")"
}

status() {
  if running; then
    echo "running (pid $(cat "$state/pid"))"
  else
    echo "not running"
  fi
  if rpc_on; then echo "discord: $(game)"; else echo "discord: off"; fi
  if have_venv; then
    echo "venv ok: $venv"
  else
    echo "no venv, run 'xvsr setup'"
  fi
  [ -f "$log" ] && tail -n 15 "$log"
  return 0
}

case "${1:-}" in
  setup) setup ;;
  start) start ;;
  stop) stop ;;
  toggle) if running; then stop; else start; fi ;;
  ab) ab ;;
  test) shift; test_file "$@" ;;
  status) status ;;
  filter) shift; filter "$@" ;;
  rpc)
    case "${2:-}" in
      on)
        rm -f "$conf/rpc-off"
        msg "discord status on"
        ;;
      off)
        mkdir -p "$conf"
        touch "$conf/rpc-off"
        pkill -TERM -f -- "$rpc_py" || true
        msg "discord status off"
        ;;
      "")
        write_rpc
        msg "showing discord status for $(game), ctrl+c to stop"
        exec "$XVSR_PYTHON" -u "$rpc_py"
        ;;
      *) die "usage: xvsr rpc [on|off]" ;;
    esac
    ;;
  game) shift; game "$@" ;;
  find)
    shift
    write_rpc
    "$XVSR_PYTHON" "$rpc_py" --find "$*" | cut -f2
    ;;
  *)
    echo "usage: xvsr setup|start|stop|toggle|ab|test FILE|status|rpc [on|off]|game [NAME]|find NAME" >&2
    exit 1
    ;;
esac

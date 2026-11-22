: "${XVSR_OUTPUT:=DP-2}"
: "${XVSR_IN:=1920x1080}"
: "${XVSR_OUT:=}"
: "${XVSR_QUALITY:=STREAMING_ULTRA}"
: "${XVSR_FPS:=60}"
: "${XVSR_FILTER_PY:?}"
: "${XVSR_PYTHON:?}"
: "${XVSR_LIBS:=}"

venv="${XDG_DATA_HOME:-$HOME/.local/share}/xvsr/venv"
state="${XDG_RUNTIME_DIR:-/tmp}/xvsr"
log="$state/xvsr.log"
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
  local win ws out hl
  win=$(cat "$state/win")
  ws=$(cat "$state/ws")
  out=$(cat "$state/out")
  hl=$(cat "$state/headless")
  rm -f "$state/win" "$state/ws" "$state/out" "$state/headless"

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

  hl=$(headless)
  if [ -z "$hl" ]; then
    swaymsg -q create_output
    hl=$(headless)
  fi
  [ -n "$hl" ] || die "couldn't create headless output"
  swaymsg -q "output $hl mode --custom ${XVSR_IN}@${XVSR_FPS}Hz position 20000 0 scale 1 enable"

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
    wf-recorder -o "$hl" -c rawvideo -x bgr0 -m rawvideo -f pipe:1 |
      (filter --in "$XVSR_IN" --in-fmt bgr0 --out "$res" --quality "$XVSR_QUALITY" --stats 10) |
      show "$res" --fs --fs-screen-name="$XVSR_OUTPUT"
    msg "$(date +%T) stopped"
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
  swaymsg -q "seat seat0 cursor set $((20000 + ${XVSR_IN%x*} / 2)) $((${XVSR_IN#*x} / 2))" || true
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

status() {
  if running; then
    echo "running (pid $(cat "$state/pid"))"
  else
    echo "not running"
  fi
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
  *)
    echo "usage: xvsr setup|start|stop|toggle|ab|test FILE|status" >&2
    exit 1
    ;;
esac

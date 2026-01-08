#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${DTND_LOG_FILE:-/var/log/dtnd.log}"
PID_FILE="${DTND_PID_FILE:-/var/run/dtnd.pid}"

NODE_NAME="${DTND_NODE_NAME:-$(hostname)}"
CLA="${DTND_CLA:-mtcp}"
ROUTING="${DTND_ROUTING:-epidemic}"
ENDPOINT="${DTND_ENDPOINT:-incoming}"
ANN_INTERVAL="${DTND_ANN_INTERVAL:-10s}"
JANITOR_INTERVAL="${DTND_JANITOR_INTERVAL:-30s}"

# Extra args appended verbatim at the end (e.g. "--debug", "--store ...", etc.)
EXTRA_ARGS="${DTND_EXTRA_ARGS:-}"

# Discovery endpoints:
# - auto (default): add -E for each IPv4 broadcast found on non-loopback UP interfaces
# - none: don't add any -E automatically
DISCOVERY_MODE="${DTND_DISCOVERY_MODE:-auto}"

# Extra endpoints added in addition to auto-discovered ones (space-separated),
# e.g. "10.250.0.3 10.2.0.255"
EXTRA_ENDPOINTS="${DTND_E_EXTRA:-}"

ts() { date -Is; }

get_ipv4_broadcasts() {
  # Output: one broadcast per line.
  # We prefer the kernel-provided "brd X" from `ip addr`.
  # For /31 there is no broadcast; for some P2P cases it may be missing -> we skip.
  ip -4 -o addr show up scope global 2>/dev/null \
    | awk '
        $2 == "lo" { next }
        {
          iface = $2
          brd = ""
          for (i=1; i<=NF; i++) {
            if ($i == "brd") { brd = $(i+1) }
          }
          if (brd != "") print brd
        }
      ' \
    | sort -u
}

start_dtnd() {
  mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")"

  # Build discovery endpoints
  endpoints=()
  if [[ "$DISCOVERY_MODE" == "auto" ]]; then
    while IFS= read -r brd; do
      [[ -n "$brd" ]] && endpoints+=("$brd")
    done < <(get_ipv4_broadcasts)
  elif [[ "$DISCOVERY_MODE" == "none" ]]; then
    :
  else
    echo "$(ts) ERROR: Unknown DTND_DISCOVERY_MODE='$DISCOVERY_MODE' (use 'auto' or 'none')" | tee -a "$LOG_FILE" >&2
    exit 2
  fi

  # Append user-provided extra endpoints
  if [[ -n "$EXTRA_ENDPOINTS" ]]; then
    # shellcheck disable=SC2206
    extra_arr=($EXTRA_ENDPOINTS)
    for e in "${extra_arr[@]}"; do
      endpoints+=("$e")
    done
  fi

  # Dedupe endpoints
  mapfile -t endpoints < <(printf "%s\n" "${endpoints[@]:-}" | awk 'NF' | sort -u)

  # Construct -E args
  E_ARGS=()
  for e in "${endpoints[@]:-}"; do
    E_ARGS+=("-E" "$e")
  done

  # If already running, don't start a second instance
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "$(ts) INFO: dtnd already running (pid $(cat "$PID_FILE"))." | tee -a "$LOG_FILE"
    exit 0
  fi

  echo "$(ts) INFO: starting dtnd name='$NODE_NAME' cla='$CLA' routing='$ROUTING' endpoint='$ENDPOINT' E=${endpoints[*]:-(none)}" \
    | tee -a "$LOG_FILE"

  # Start dtnd
  # NOTE: use nohup + background and write PID file
  nohup dtnd \
    -n "$NODE_NAME" \
    -C "$CLA" \
    -r "$ROUTING" \
    -e "$ENDPOINT" \
    -i "$ANN_INTERVAL" \
    -j "$JANITOR_INTERVAL" \
    "${E_ARGS[@]}" \
    $EXTRA_ARGS \
    >>"$LOG_FILE" 2>&1 &

  echo $! >"$PID_FILE"
  echo "$(ts) INFO: dtnd started pid=$(cat "$PID_FILE")" | tee -a "$LOG_FILE"
}

stop_dtnd() {
  if [[ -f "$PID_FILE" ]]; then
    pid="$(cat "$PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
      echo "$(ts) INFO: stopping dtnd pid=$pid" | tee -a "$LOG_FILE"
      kill "$pid" 2>/dev/null || true
      # give it a moment, then hard kill if needed
      sleep 1
      kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi
  # fallback
  killall dtnd 2>/dev/null || true
}

case "${1:-start}" in
  start) start_dtnd ;;
  stop)  stop_dtnd ;;
  restart) stop_dtnd; start_dtnd ;;
  *)
    echo "usage: $0 {start|stop|restart}" >&2
    exit 2
    ;;
esac

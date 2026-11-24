#!/usr/bin/env bash
# vps-wait.sh: wait for a cloud server to settle. Polls vps_get and prints each
# state change until the server is running or stopped, reports an error state,
# or the timeout passes. Read-only. Never prints a tunnel_token or a password.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: vps-wait.sh NAME_OR_VPS_ID [--timeout SECONDS] [--interval SECONDS]

Polls vps_get and prints a line each time the state or its detail changes.
  exit 0  the server is running or stopped
  exit 1  the server reports the error or suspended state, or an API call failed
  exit 2  bad arguments
  exit 3  the timeout passed first (the last state is printed)

  --timeout SECONDS   stop waiting after this long (default 100, under a 2-minute tool limit)
  --interval SECONDS  time between polls, 1 or more (default 10)
  -h, --help          show this help

States: pending, provisioning, starting, booting, running, stopping, stopped,
restarting, suspended, destroying, error.
Calls: vps_list (once, to find the server), then vps_get. Needs curl and jq.
EOF
}

target=""
timeout=100
interval=10
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) [ $# -ge 2 ] || { usage >&2; exit 2; }; timeout="$2"; shift 2 ;;
    --timeout=*) timeout="${1#--timeout=}"; shift ;;
    --interval) [ $# -ge 2 ] || { usage >&2; exit 2; }; interval="$2"; shift 2 ;;
    --interval=*) interval="${1#--interval=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) usage >&2; exit 2 ;;
    *) [ -z "$target" ] || { usage >&2; exit 2; }; target="$1"; shift ;;
  esac
done
[ -n "$target" ] || { usage >&2; exit 2; }
for v in "$timeout" "$interval"; do
  case "$v" in ''|*[!0-9]*) echo "vps-wait: --timeout and --interval take whole seconds" >&2; exit 2 ;; esac
done
# Base 10: a leading zero ("08") would otherwise read as octal.
timeout=$((10#$timeout))
interval=$((10#$interval))
[ "$interval" -ge 1 ] || { echo "vps-wait: --interval must be 1 or more" >&2; exit 2; }

# lib/doxx.sh sits in ../lib in a generated skill and in ../../../lib under src/.
# shellcheck source-path=SCRIPTDIR/../lib source-path=SCRIPTDIR/../../../lib source=doxx.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/doxx.sh"
doxx_require

# Server names are unique in an account; a vps_id also matches.
doxx_call vps_list
match="$(printf '%s' "$DOXX_OUT" | jq -r --arg t "$target" \
  '[.servers[]? | select(.name == $t or .vps_id == $t)] | if length == 1 then "\(.[0].vps_id)\t\(.[0].name)" else empty end')"
[ -n "$match" ] || doxx_die "no single server named or with id '$target' (list them with vps_list)"
id="${match%%$'\t'*}"
name="${match#*$'\t'}"

started="$(date +%s)"
last=""
while :; do
  doxx_call vps_get "vps_id=$id"
  line="$(printf '%s' "$DOXX_OUT" | jq -r '"\(.vps.state) \(.vps.detail // "")" | sub(" +$"; "")')"
  state="${line%% *}"
  if [ "$line" != "$last" ]; then
    printf '%s %s: %s\n' "$(date -u +%H:%M:%SZ)" "$name" "$line"
    last="$line"
  fi
  case "$state" in
    running|stopped) exit 0 ;;
    error|suspended)
      echo "vps-wait: $name is $line" >&2
      exit 1 ;;
  esac
  if [ $(( $(date +%s) - started + interval )) -gt "$timeout" ]; then
    echo "vps-wait: still '$state' after ${timeout}s; run again or check vps_get later" >&2
    exit 3
  fi
  sleep "$interval"
done

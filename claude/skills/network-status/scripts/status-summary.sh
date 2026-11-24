#!/usr/bin/env bash
# status-summary.sh: one table of the user's tunnels with peak bandwidth and
# alert counts, plus an account-wide alerts summary. Read-only. Prints tunnel
# names only, never tunnel_token or private_key values.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: status-summary.sh [--last 1m|1h|1d|24h|7d|30d]

One table, one row per tunnel (by name): server, address, connected or not,
peak inbound and outbound Mbps, and the number of alerts. Then the alert
totals by category and the top alerts. Read-only.

  --last WINDOW   time window for bandwidth and alerts (default 1h)
  -h, --help      show this help

Calls: list_tunnels, Stats bandwidth (start/end), Stats alerts (last).
Needs curl and jq (>= 1.6).
EOF
}

last="1h"
while [ $# -gt 0 ]; do
  case "$1" in
    --last) [ $# -ge 2 ] || { usage >&2; exit 2; }; last="$2"; shift 2 ;;
    --last=*) last="${1#--last=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

case "$last" in
  1m) secs=60 ;;
  1h) secs=3600 ;;
  1d|24h) secs=86400 ;;
  7d) secs=604800 ;;
  30d) secs=2592000 ;;
  *) echo "status-summary: --last must be 1m, 1h, 1d, 24h, 7d or 30d" >&2; exit 2 ;;
esac

# lib/doxx.sh sits in ../lib in a generated skill and in ../../../lib under src/.
# shellcheck source-path=SCRIPTDIR/../lib source-path=SCRIPTDIR/../../../lib source=doxx.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/doxx.sh"
doxx_require

doxx_call list_tunnels
tunnels="$DOXX_OUT"
start="$(doxx_ago "$secs")"
end="$(doxx_ago 0)"
doxx_stats bandwidth "start=$start" "end=$end"
bandwidth="$DOXX_OUT"
doxx_stats alerts "last=$last"
alerts="$DOXX_OUT"

echo "doxx.net status, last $last ($start to $end)"
echo
# Join on tunnel_token inside jq; only names and safe fields leave it.
printf '%s\n%s\n%s' "$tunnels" "$bandwidth" "$alerts" | jq -rs '
  def r2: if . == null then "-" else ((. * 100 + 0.5) | floor) / 100 | tostring end;
  (.[0].tunnels // []) as $t | (.[1].data // []) as $b | (.[2].data // []) as $a |
  (["TUNNEL", "SERVER", "ADDRESS", "CONNECTED", "PEAK_IN_MBPS", "PEAK_OUT_MBPS", "ALERTS"] | @tsv),
  (if ($t | length) == 0 then (["(no tunnels)"] | @tsv) else empty end),
  ($t[] | .tunnel_token as $k |
    [ (.name // "-"), (.server // "-"), ((.assigned_ip // "-") | split("/")[0]),
      (if .is_connected then "yes" else "no" end),
      ([$b[] | select(.tunnel_token == $k) | .peak_in] | max | r2),
      ([$b[] | select(.tunnel_token == $k) | .peak_out] | max | r2),
      ([$a[] | select(.tunnel_token == $k) | .count] | add // 0 | tostring)
    ] | map(if . == "" then "-" else . end) | @tsv)
' | doxx_table

echo
doxx_names -r "$tunnels" "$alerts" '
  "alerts: \(.block_count // 0) events" +
  (if ((.category_counts // {}) | length) > 0
   then "; by category: " + ([.category_counts | to_entries | sort_by(-.value)[] | "\(.key) \(.value)"] | join(", "))
   else "" end),
  ((.data // [])[:5][] | "  \(.tunnel): \(.value) (\(.type), \(.category // "-"), \(.action // "-")) x\(.count)")
'

#!/usr/bin/env bash
# snapshot.sh: read-before-write snapshot of the account's tunnels, firewall
# rules, Full Mesh state and DNS blocking settings, saved to a private (0600)
# JSON file. Prints only the file path and counts. Read-only on the API.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: snapshot.sh [--no-dns]

Saves the current state before a change, so any setting can be restored:
  tunnels        list_tunnels (include_vps=1), WireGuard private keys removed
  firewall       every firewall rule and the Full Mesh state
  dns            dns_get_all_tunnel_configs (skip with --no-dns)

The file is ${XDG_STATE_HOME:-~/.local/state}/doxx/snapshots/<UTC time>.json,
mode 0600. It holds tunnel_token values (needed to restore a tunnel), so it is
a secret: never print it whole; read single fields with jq. This script
prints only the path and the counts.

  --no-dns     leave out the DNS blocking configuration
  -h, --help   show this help

Calls: list_tunnels, firewall_rule_list (once; once per tunnel when Full Mesh
is on), dns_get_all_tunnel_configs. Needs curl and jq (>= 1.6).
EOF
}

dns=1
while [ $# -gt 0 ]; do
  case "$1" in
    --no-dns) dns=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

# lib/doxx.sh sits in ../lib in a generated skill and in ../../../lib under src/.
# shellcheck source-path=SCRIPTDIR/../lib source-path=SCRIPTDIR/../../../lib source=doxx.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/doxx.sh"
doxx_require

doxx_call list_tunnels include_vps=1
tunnels="$DOXX_OUT"
doxx_firewall_rules "$tunnels"
firewall="$DOXX_OUT"
dnsconf='null'
if [ "$dns" = 1 ]; then
  doxx_call dns_get_all_tunnel_configs
  dnsconf="$DOXX_OUT"
fi

dir="${XDG_STATE_HOME:-$HOME/.local/state}/doxx/snapshots"
(umask 077 && mkdir -p "$dir")
chmod 700 "$dir"
taken="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
file="$dir/$(date -u +%Y%m%dT%H%M%SZ).json"
n=1
while [ -e "$file" ]; do
  file="$dir/$(date -u +%Y%m%dT%H%M%SZ)-$n.json"
  n=$((n + 1))
done

# Drop private keys and the per-call `context` text; keep everything a restore needs.
(umask 077 && printf '%s\n%s\n%s' "$tunnels" "$firewall" "$dnsconf" | jq -s --arg taken "$taken" '{
  taken_at: $taken,
  note: "doxx.net state snapshot. Holds tunnel_token values: keep it private.",
  tunnels: [(.[0].tunnels // [])[] | del(.private_key)],
  link_all_enabled: .[1].link_all_enabled,
  firewall_rules: .[1].rules,
  dns: (if .[2] == null then null else .[2] | del(.status, .context) end)
}' > "$file")
chmod 600 "$file"

echo "snapshot: $file"
jq -r '"tunnels: \(.tunnels | length), firewall rules: \(.firewall_rules | length), Full Mesh: \(if .link_all_enabled then "on" else "off" end), DNS configs: \(if .dns == null then "skipped" else (.dns.tunnels // [] | length) end)"' "$file"

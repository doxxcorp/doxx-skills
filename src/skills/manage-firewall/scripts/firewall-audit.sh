#!/usr/bin/env bash
# firewall-audit.sh: every firewall rule of the account in one table by tunnel
# name, with flags for ports open to the internet, rules pinned to one source
# address, and tunnels whose firewall is off. Read-only. Never prints a
# tunnel_token or private_key.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: firewall-audit.sh

Lists the firewall rules of every tunnel and cloud server (by name) and flags:
  OPEN-ALL     every port open to the whole internet
  OPEN         a port open to the whole internet
  PINNED-SRC   source pinned to one public address (breaks when that address changes)
  FIREWALL-OFF the tunnel's firewall is off: all inbound traffic is allowed
The STATE column is "disabled" for a rule that is kept but not enforced.
With Full Mesh on, the API lists only enforced rules: the tunnel-to-tunnel
rules Full Mesh parked are not shown (their count is rules_dormant in the
firewall_link_all_toggle answer). Also prints whether Full Mesh is on.
Read-only.

  -h, --help   show this help

Calls: list_tunnels (include_vps=1), firewall_rule_list (once; once per
tunnel when Full Mesh is on). Needs curl and jq (>= 1.6).
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
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
rules="$DOXX_OUT"

# One jq pass builds the report. Rules are joined to tunnels by tunnel_token,
# so two tunnels with the same name never share rows; only names and rule
# fields leave jq, never a token.
report="$(printf '%s\n%s' "$tunnels" "$rules" | jq -cs '
  def any_src: (. // "" | ascii_downcase) as $s | ["0.0.0.0/0", "0.0.0.0", "::/0", "::", "all", "any", ""] | index($s) != null;
  def all_ports: (. // "" | tostring | ascii_downcase) as $p | ($p == "all" or $p == "" or $p == "0" or $p == "1-65535");
  def host: (. // "") | split("/")[0];
  def private: test("^(10\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.|f[cd])"; "i");
  def single: (contains("/") | not) or test("/(32|128)$");
  def state: if .enabled == false then "disabled" else "active" end;
  (.[0].tunnels // []) as $t | .[1] as $r |
  ([$t[] | .name as $n | (.assigned_ip, .assigned_v6) | select((. // "") != "") | {key: host, value: $n}] | from_entries) as $ip2name |
  ($r.rules // []) as $rules |
  [$rules[] | . as $x | ($x.src_ip // "") as $src | $ip2name[$src | host] as $peer |
    $x + {
      flag: (if ($src | any_src) then (if ($x.dst_port | all_ports) then "OPEN-ALL" else "OPEN" end)
             elif $peer then "" elif ($src | private) then "" elif ($src | single) then "PINNED-SRC" else "" end),
      source: ((if ($src | any_src) then "internet" elif $peer then "\($src) (\($peer))" else $src end)
               + (if ($x.src_port | all_ports) then "" else ":\($x.src_port)" end))
    }] as $rows |
  [$t[].tunnel_token] as $known |
  {
    mesh: $r.link_all_enabled,
    table: (
      [["TUNNEL", "FIREWALL", "PROTO", "SOURCE", "DEST", "PORT", "STATE", "FLAGS"]] +
      [$t[] | . as $tun | (if $tun.firewall == 0 then "off" else "on" end) as $fw |
        (if $tun.firewall == 0 then ["FIREWALL-OFF"] else [] end) as $tflag |
        [$rows[] | select(.tunnel_token == $tun.tunnel_token)] as $mine |
        if ($mine | length) == 0 then [$tun.name, $fw, "-", "-", "-", "-", "(no rules)", ($tflag | join(","))]
        else $mine[] | [$tun.name, $fw, (.protocol // "ALL"), .source, (.dst_ip // "-"), (.dst_port // "ALL" | tostring), state,
                        ($tflag + (if .flag == "" then [] else [.flag] end) | join(","))]
        end] +
      [$rows[] | select(.tunnel_token as $k | $known | index($k) | not) |
        ["unknown tunnel", "?", (.protocol // "ALL"), .source, (.dst_ip // "-"), (.dst_port // "ALL" | tostring), state, .flag]]
    ),
    summary: "tunnels \($t | length), rules \($rules | length), open to the internet \([$rows[] | select(.flag | startswith("OPEN"))] | length) (every port \([$rows[] | select(.flag == "OPEN-ALL")] | length)), pinned source \([$rows[] | select(.flag == "PINNED-SRC")] | length), firewall off \([$t[] | select(.firewall == 0)] | length)"
  }')"

printf '%s' "$report" | jq -r 'if .mesh then "Full Mesh: on. Tunnels reach each other without rules; tunnel-to-tunnel rules it parked are not listed in this mode (the count is rules_dormant from firewall_link_all_toggle)." else "Full Mesh: off." end'
echo
printf '%s' "$report" | jq -r '.table[] | map(if . == "" then "-" else . end) | @tsv' | doxx_table
echo
printf '%s' "$report" | jq -r '"summary: " + .summary'

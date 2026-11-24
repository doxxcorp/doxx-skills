# shellcheck shell=bash
#
# doxx.sh: shared helpers for the doxx.net skill scripts (Code Mode).
#
# Source it from a script in <skill>/scripts/:
#
#   . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/doxx.sh"
#
# `make build` copies this file to <runtime>/skills/<skill>/lib/doxx.sh for
# every skill that ships a scripts/ directory, so the path above holds in every
# generated skill. Edit it here (src/lib/doxx.sh) only.
#
# Calls (each sets DOXX_OUT to the JSON answer and records the call):
#
#   doxx_call ENDPOINT [key=value ...]   Config API: POST, form-encoded, token from stdin
#   doxx_stats ENDPOINT [key=value ...]  Stats API: query-string params, X-Auth-Token header from stdin
#
# On failure both print "doxx: <endpoint>: <API message>" to stderr and return 1,
# so a script under `set -e` stops at the first error. Call them as plain
# commands (not inside $(...)): they set DOXX_OUT in the current shell.
#
# Secrets: the auth token and every key=value param go to curl as a config on
# stdin (`curl -K -`, written by doxx__cfg), so no token, tunnel_token or other
# param value is ever in curl's arguments, and none is printed. Answers may hold
# tunnel_token and private_key values: scripts must select fields with jq
# before printing.
#
# Test-only overrides (never set these in normal use):
#   DOXX_API_BASE    Config API URL   (default https://config.doxx.net/v1/)
#   DOXX_STATS_BASE  Stats API prefix (default https://secure-wss.doxx.net/api/stats)
# Both are refused unless they point at https://<host>.doxx.net/ or at
# http://127.0.0.1 or http://localhost (any port), so a stray environment
# variable cannot send the token anywhere else.

DOXX_API_BASE="${DOXX_API_BASE:-https://config.doxx.net/v1/}"
DOXX_STATS_BASE="${DOXX_STATS_BASE:-https://secure-wss.doxx.net/api/stats}"
DOXX_OUT=""
DOXX_CALLS=""
DOXX_CURL_LIMITS=(--connect-timeout 10 --max-time 60)

# The canonical token expansion (src/partials/transport.md): DOXX_TOKEN,
# ~/.config/doxx/token, DOXXNET_TOKEN, ~/.config/doxxnet/token. Only ever piped.
doxx__token() {
  printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}"
}

doxx_die() {
  printf 'doxx: %s\n' "$*" >&2
  exit 1
}

# Checks the tools and that a token is configured (without printing it).
# Without jq, Code Mode is off: the agent falls back to single calls.
doxx__check_base() {
  local url="$2" scheme host
  scheme="${url%%://*}"
  host="${url#*://}"
  host="${host%%/*}"
  case "$scheme:$host" in
    *[!A-Za-z0-9.:-]*) ;;
    https:*.doxx.net) return 0 ;;
    http:127.0.0.1|http:localhost) return 0 ;;
    http:127.0.0.1:*|http:localhost:*)
      case "${host#*:}" in ''|*[!0-9]*) ;; *) return 0 ;; esac ;;
  esac
  doxx_die "$1 must be an https://<host>.doxx.net URL (or http://127.0.0.1 / http://localhost for tests); refusing to send the token to '$url'"
}

doxx_require() {
  doxx__check_base DOXX_API_BASE "$DOXX_API_BASE"
  doxx__check_base DOXX_STATS_BASE "$DOXX_STATS_BASE"
  command -v curl >/dev/null 2>&1 || doxx_die "curl is required"
  command -v jq >/dev/null 2>&1 || doxx_die "jq is required for the bundled scripts: install jq, or make single calls instead"
  [ -n "$(doxx__token)" ] || doxx_die "no doxx.net token found (DOXX_TOKEN, ~/.config/doxx/token, DOXXNET_TOKEN or ~/.config/doxxnet/token)"
  trap doxx__report EXIT
}

doxx__record() {
  DOXX_CALLS="${DOXX_CALLS}${1}
"
}

# Printed on exit: every endpoint the script called, with a count.
doxx__report() {
  [ -n "$DOXX_CALLS" ] || return 0
  printf 'endpoints called: %s\n' "$(printf '%s' "$DOXX_CALLS" | awk '
    { if (!($0 in n)) order[++k] = $0; n[$0]++ }
    END { for (i = 1; i <= k; i++) printf "%s%s%s", (i > 1 ? ", " : ""), order[i], (n[order[i]] > 1 ? " x" n[order[i]] : "") }')"
}

doxx__check_kv() {
  case "$1" in
    [a-z_]*=*) ;;
    *) doxx_die "bad parameter '${1%%=*}': use key=value" ;;
  esac
}

# doxx__cfg OPTION VALUE: one curl config line (`OPTION = "VALUE"`). Backslash,
# double quote, newline and carriage return are escaped, so any value reads
# back exactly as given.
doxx__cfg() {
  local v="$2"
  v="${v//\\/\\\\}"
  v="${v//\"/\\\"}"
  v="${v//$'\n'/\\n}"
  v="${v//$'\r'/\\r}"
  printf '%s = "%s"\n' "$1" "$v"
}

# doxx__split OUT: splits curl output that ends in "\n<http code>" (-w) into
# DOXX__CODE and DOXX__BODY.
doxx__split() {
  DOXX__CODE="${1##*$'\n'}"
  DOXX__BODY="${1%$'\n'*}"
}

doxx_call() {
  local ep="$1" kv out rc
  shift
  for kv in "$@"; do
    doxx__check_kv "$kv"
  done
  doxx__record "$ep"
  rc=0
  out="$(
    {
      for kv in "$@"; do
        doxx__cfg data-urlencode "$kv"
      done
      doxx__cfg data-urlencode "token=$(doxx__token)"
    } | curl -s "${DOXX_CURL_LIMITS[@]}" -X POST "$DOXX_API_BASE" -d "$ep=1" -K - -w '\n%{http_code}'
  )" || rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'doxx: %s: request failed (curl exit %s)\n' "$ep" "$rc" >&2
    return 1
  fi
  doxx__split "$out"
  # Errors are JSON with status "error", sent with HTTP 200 or a 4xx code; a
  # body that is not a JSON object (a proxy's 502 or 503 page) is reported with
  # its HTTP code.
  if ! printf '%s' "$DOXX__BODY" | jq -e 'type == "object"' >/dev/null 2>&1; then
    printf 'doxx: %s: unexpected answer (HTTP %s): %.200s\n' "$ep" "$DOXX__CODE" "$DOXX__BODY" >&2
    return 1
  fi
  if [ "$(printf '%s' "$DOXX__BODY" | jq -r '.status // ""')" != "success" ]; then
    printf 'doxx: %s: error: %s\n' "$ep" "$(printf '%s' "$DOXX__BODY" | jq -r '.message // .error // "no message"')" >&2
    return 1
  fi
  DOXX_OUT="$DOXX__BODY"
}

doxx_stats() {
  local ep="$1" kv qs="" out rc
  shift
  for kv in "$@"; do
    doxx__check_kv "$kv"
    qs="${qs}&${kv%%=*}=$(printf '%s' "${kv#*=}" | jq -sRj @uri)"
  done
  doxx__record "stats/$ep"
  rc=0
  # The URL rides in the config too: a tunnel_token param would otherwise be in
  # curl's arguments.
  out="$(
    {
      doxx__cfg url "$DOXX_STATS_BASE/$ep?${qs#&}"
      doxx__cfg header "X-Auth-Token: $(doxx__token)"
    } | curl -s "${DOXX_CURL_LIMITS[@]}" -K - -X POST -w '\n%{http_code}'
  )" || rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'doxx: stats/%s: request failed (curl exit %s)\n' "$ep" "$rc" >&2
    return 1
  fi
  doxx__split "$out"
  if [ "$DOXX__CODE" != "200" ] || ! printf '%s' "$DOXX__BODY" | jq -e 'type == "object"' >/dev/null 2>&1; then
    printf 'doxx: stats/%s: error (HTTP %s): %.200s\n' "$ep" "$DOXX__CODE" "$DOXX__BODY" >&2
    return 1
  fi
  DOXX_OUT="$DOXX__BODY"
}

# The Stats recipe's token-to-name map (src/partials/stats-api.md uses the same
# text, checked by tests/run.sh). Input: a slurped pair [list_tunnels answer,
# Stats answer]. Output: the Stats answer with every tunnel_token replaced by a
# `tunnel` name, by_tunnel keys renamed, tunnel_tokens dropped. Duplicate
# tunnel names get a suffix ("alpha", "alpha (2)", ...) in list order, so
# by_tunnel keys never collide. Needs jq >= 1.6.
# shellcheck disable=SC2016
DOXX_JQ_NAMES='(reduce (.[0].tunnels // [] | .[] | select(.tunnel_token != null)) as $t ({m: {}, u: {}}; .u as $u | ($t.name // "unnamed tunnel") as $b | (if $u[$b] then first(range(2; infinite) | "\($b) (\(.))" | select($u[.] | not)) else $b end) as $k | .m[$t.tunnel_token] = $k | .u[$k] = true) | .m) as $n | .[1] | del(.tunnel_tokens) | walk(if type == "object" then (if has("tunnel_token") then .tunnel = (if .tunnel_token == "aggregate" then "all tunnels" else ($n[.tunnel_token // ""] // "unknown tunnel") end) | del(.tunnel_token) else . end) | (if (.by_tunnel | type) == "object" then .by_tunnel |= (to_entries | [foreach .[] as $e (0; if $n[$e.key] then . else . + 1 end; {key: ($n[$e.key] // "unknown tunnel \(.)"), value: $e.value})] | from_entries) else . end) else . end)'

# doxx_names [-r] TUNNELS_JSON ANSWER_JSON [FILTER]: the answer with tokens
# mapped to names, then FILTER (default `.`). -r prints raw strings.
doxx_names() {
  local raw=""
  if [ "$1" = "-r" ]; then raw="-r"; shift; fi
  printf '%s\n%s' "$1" "$2" | jq ${raw:+"$raw"} -s "$DOXX_JQ_NAMES | ${3:-.}"
}

# doxx_firewall_rules TUNNELS_JSON: every firewall rule of the account, as
# {link_all_enabled, rules} in DOXX_OUT. With Full Mesh off, one
# firewall_rule_list call returns every rule, disabled ones (enabled: false)
# included. With Full Mesh on, a call without tunnel_token answers rules: null,
# so this calls firewall_rule_list once per tunnel in TUNNELS_JSON, one at a
# time; each answer holds only that tunnel's enforced rules, never the
# tunnel-to-tunnel rules Full Mesh parked. `rules` is null when empty in both
# modes, hence the `// []`.
doxx_firewall_rules() {
  local tunnels="$1" tt rules list
  doxx_call firewall_rule_list || return 1
  if [ "$(printf '%s' "$DOXX_OUT" | jq -r '.link_all_enabled')" != "true" ]; then
    DOXX_OUT="$(printf '%s' "$DOXX_OUT" | jq -c '{link_all_enabled: false, rules: (.rules // [])}')"
    return 0
  fi
  rules='[]'
  list="$(printf '%s' "$tunnels" | jq -r '.tunnels[]?.tunnel_token // empty')"
  while IFS= read -r tt; do
    [ -n "$tt" ] || continue
    doxx_call firewall_rule_list "tunnel_token=$tt" || return 1
    rules="$(printf '%s\n%s' "$rules" "$DOXX_OUT" | jq -cs '.[0] + (.[1].rules // [])')"
  done <<EOF_TT
$list
EOF_TT
  DOXX_OUT="$(printf '%s' "$rules" | jq -c '{link_all_enabled: true, rules: .}')"
}

# doxx_ago SECONDS: the RFC3339 UTC time SECONDS ago (jq keeps it portable).
doxx_ago() {
  jq -nr --arg s "$1" '(now - ($s | tonumber)) | floor | todate'
}

# doxx_table: tab-separated rows on stdin, aligned with `column` when present.
doxx_table() {
  if command -v column >/dev/null 2>&1; then
    column -t -s "$(printf '\t')"
  else
    cat
  fi
}

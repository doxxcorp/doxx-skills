#!/usr/bin/env bash
# Tests for the Code Mode scripts, run against the generated claude/ tree (run
# `make build` first; `make test` does). No network: the scripts talk to
# tests/fake_api.py through the test-only DOXX_API_BASE / DOXX_STATS_BASE
# overrides, with a throwaway HOME so no real token file is read.
# Checks are strings run by `check` through eval, so their $VARS are meant to stay
# unexpanded until then (SC2016), and variables read only inside them look unused
# to shellcheck (SC2034).
# shellcheck disable=SC2016,SC2034
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS="$REPO_ROOT/claude/skills"
FAILS=0
PASSES=0

pass() { PASSES=$((PASSES + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAILS=$((FAILS + 1)); printf '  FAIL %s\n' "$1"; }
check() { if eval "$2"; then pass "$1"; else fail "$1"; fi; }

for cmd in python3 jq curl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "tests: $cmd is required" >&2; exit 1; }
done

SCRIPTS=(
  network-status/scripts/status-summary.sh
  manage-firewall/scripts/firewall-audit.sh
  doxxnet/scripts/snapshot.sh
  manage-vps/scripts/vps-wait.sh
)

WORK="$(mktemp -d)"
SERVER_PID=""

# A curl shim first on PATH logs every curl command line ("$*") before it runs
# the real curl, so the tests can prove that no token or other secret is ever in
# curl's arguments (the process list shows them to every user of the machine).
REAL_CURL="$(command -v curl)"
ARGV_LOG="$WORK/argv.log"
mkdir -p "$WORK/bin"
cat > "$WORK/bin/curl" <<EOF_SHIM
#!/usr/bin/env bash
printf '%s\n' "\$*" >> '$ARGV_LOG'
exec '$REAL_CURL' "\$@"
EOF_SHIM
chmod +x "$WORK/bin/curl"
TEST_PATH="$WORK/bin:$PATH"
: > "$ARGV_LOG"
cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "syntax and --help"
for s in "${SCRIPTS[@]}"; do
  check "$s: bash -n" "bash -n '$SKILLS/$s'"
  check "$s: lib next to it" "[ -f '$SKILLS/${s%%/*}/lib/doxx.sh' ]"
  check "$s: --help" "bash '$SKILLS/$s' --help | grep -q '^Usage:'"
done
check "lib: bash -n" "bash -n '$REPO_ROOT/src/lib/doxx.sh'"

echo "partial and lib share the token-to-name filter"
filter="$(bash -c '. "$1"; printf %s "$DOXX_JQ_NAMES"' _ "$REPO_ROOT/src/lib/doxx.sh")"
check "stats-api.md recipe uses DOXX_JQ_NAMES verbatim" \
  "grep -Fq -- \"\$filter | FILTER'\" '$REPO_ROOT/src/partials/stats-api.md'"

echo "token-to-name filter: duplicate tunnel names"
dup_stats='{"tunnel_tokens":["SECRET-TT-A","SECRET-TT-B"],"data":[{"tunnel_token":"SECRET-TT-A"},{"tunnel_token":"SECRET-TT-B"}],"by_tunnel":{"SECRET-TT-A":{"peak_in":1},"SECRET-TT-B":{"peak_in":2}}}'
dup_out="$(bash -c '. "$1"; doxx_names "$(cat "$2")" "$3"' _ "$REPO_ROOT/src/lib/doxx.sh" "$REPO_ROOT/tests/fixtures/dupnames/list_tunnels.json" "$dup_stats" 2>&1 || true)"
check "by_tunnel keeps both tunnels, suffixed" \
  "[ \"\$(printf '%s' \"\$dup_out\" | jq -c '.by_tunnel | to_entries | map([.key, .value.peak_in])')\" = '[[\"alpha\",1],[\"alpha (2)\",2]]' ]"
check "rows carry the same suffixed names" \
  "[ \"\$(printf '%s' \"\$dup_out\" | jq -c '[.data[].tunnel]')\" = '[\"alpha\",\"alpha (2)\"]' ]"
check "no token left in the mapped answer" "! printf '%s' \"\$dup_out\" | grep -q SECRET"

echo "token-to-name filter: a null tunnel_token"
null_out="$(bash -c '. "$1"; doxx_names "$(cat "$2")" "$3"' _ "$REPO_ROOT/src/lib/doxx.sh" "$REPO_ROOT/tests/fixtures/dupnames/list_tunnels.json" '{"data":[{"tunnel_token":null,"peak_in":1}]}' 2>&1 || true)"
check "a row with tunnel_token null maps to unknown tunnel" "[ \"\$(printf '%s' \"\$null_out\" | jq -r '.data[0].tunnel' 2>/dev/null)\" = 'unknown tunnel' ]"

# ─── fake API ────────────────────────────────────────────────────────────────

LOG="$WORK/requests.log"
: > "$LOG"
python3 "$REPO_ROOT/tests/fake_api.py" "$REPO_ROOT/tests/fixtures" "$WORK/port" "$LOG" 2> "$WORK/fake_api.err" &
SERVER_PID=$!
# Up to 30 s: a cold python3 start on a busy CI runner can take several seconds.
for _ in $(seq 1 300); do
  [ -s "$WORK/port" ] && break
  kill -0 "$SERVER_PID" 2>/dev/null || break
  sleep 0.1
done
if [ ! -s "$WORK/port" ]; then
  echo "tests: fake API did not start" >&2
  cat "$WORK/fake_api.err" >&2
  exit 1
fi
PORT="$(cat "$WORK/port")"

# All fixture secrets start with SECRET; the account token is test-token.
SECRETS_RE='SECRET\|test-token'
no_secrets() { ! printf '%s' "$OUT" | grep -q "$SECRETS_RE"; }
# The leak detector: no fixture secret in any logged curl command line.
argv_clean() { ! grep -q "$SECRETS_RE" "$ARGV_LOG"; }

# run_at SKILLS_DIR SCENARIO SCRIPT [args...]: runs a script against the fake
# API, output in $OUT, exit code in $RC, curl command lines in $ARGV_LOG.
run_at() {
  local skills="$1" scenario="$2" script="$3"
  shift 3
  RC=0
  : > "$ARGV_LOG"
  OUT="$(env -i PATH="$TEST_PATH" HOME="$WORK/home" DOXX_TOKEN=test-token \
    DOXX_API_BASE="http://127.0.0.1:$PORT/$scenario/v1/" \
    DOXX_STATS_BASE="http://127.0.0.1:$PORT/$scenario/api/stats" \
    bash "$skills/$script" "$@" 2>&1)" || RC=$?
}

# run SCENARIO SCRIPT [args...]: run_at on the generated skills. Every run, error
# paths included, must leak no fixture token or private key, neither in its
# output nor in a curl command line.
run() {
  run_at "$SKILLS" "$@"
  check "[$1] ${2##*/} ${*:3}: no token or key in output" no_secrets
  check "[$1] ${2##*/} ${*:3}: no token in a curl command line" argv_clean
}
mkdir -p "$WORK/home"
log_lines() { jq -c "select(.scenario == \"$1\")" "$LOG"; }

echo "status-summary.sh"
run basic network-status/scripts/status-summary.sh --last 1h
check "exit 0" '[ "$RC" -eq 0 ]'
check "the curl shim logged the calls (the argv check is live)" "[ \"\$(wc -l < '$ARGV_LOG' | tr -d ' ')\" = 3 ]"
check "laptop row: peaks 12.35 / 4.75, 40 alerts" "printf '%s' \"\$OUT\" | grep -Eq '^laptop +mia1.doxx.net +10\.1\.0\.2 +yes +12\.35 +4\.75 +40'"
check "homeserver row: 1.5 / 0.25, 2 alerts" "printf '%s' \"\$OUT\" | grep -Eq '^homeserver .* no +1\.5 +0\.25 +2$'"
check "oldbox row: no data" "printf '%s' \"\$OUT\" | grep -Eq '^oldbox .* - +- +0$'"
check "alert summary by category" "printf '%s' \"\$OUT\" | grep -q 'alerts: 42 events; by category: ads 30, tracking 10, security 2'"
check "top alert named by tunnel" "printf '%s' \"\$OUT\" | grep -q 'laptop: ads.example.com (dns_block, ads, block) x30'"
check "endpoints called line" "printf '%s' \"\$OUT\" | grep -q '^endpoints called: list_tunnels, stats/bandwidth, stats/alerts$'"
check "bandwidth sent start and end, no last" \
  "log_lines basic | jq -e 'select(.endpoint == \"bandwidth\") | (.query.start | test(\"Z$\")) and (.query.end | test(\"Z$\")) and (.query | has(\"last\") | not)' >/dev/null"
check "alerts sent last=1h" "log_lines basic | jq -e 'select(.endpoint == \"alerts\") | .query.last == \"1h\"' >/dev/null"
check "stats auth by header, no token in any URL" \
  "log_lines basic | jq -se 'map(select(.api == \"stats\")) | length > 0 and all(.auth_header and (.query | has(\"token\") or has(\"auth_token\") or has(\"tunnel_token\") | not))' >/dev/null"
run basic network-status/scripts/status-summary.sh --last 2h
check "--last 2h refused (exit 2)" '[ "$RC" -eq 2 ]'

echo "firewall-audit.sh (Full Mesh off)"
: > "$LOG"
run basic manage-firewall/scripts/firewall-audit.sh
check "exit 0" '[ "$RC" -eq 0 ]'
check "Full Mesh off" "printf '%s' \"\$OUT\" | grep -q '^Full Mesh: off.'"
check "443 open to the internet: OPEN" "printf '%s' \"\$OUT\" | grep -Eq '^homeserver +on +TCP +internet +203\.0\.113\.10 +443 +active +OPEN$'"
check "every port from ::/0: OPEN-ALL" "printf '%s' \"\$OUT\" | grep -Eq '^homeserver .* internet .* ALL +active +OPEN-ALL$'"
check "single public source: PINNED-SRC" "printf '%s' \"\$OUT\" | grep -Eq '198\.51\.100\.7/32 .* PINNED-SRC$'"
check "tunnel source named, disabled" "printf '%s' \"\$OUT\" | grep -Eq '10\.1\.0\.2 \(laptop\) +10\.1\.0\.3 +22 +disabled +-$'"
check "firewall off flagged" "printf '%s' \"\$OUT\" | grep -Eq '^oldbox +off .*\(no rules\) +FIREWALL-OFF$'"
check "rule of an unlisted tunnel" "printf '%s' \"\$OUT\" | grep -Eq '^unknown tunnel +\?'"
check "summary counts" "printf '%s' \"\$OUT\" | grep -q 'summary: tunnels 3, rules 5, open to the internet 2 (every port 1), pinned source 1, firewall off 1'"
check "one firewall_rule_list call" "[ \"\$(log_lines basic | jq -s 'map(select(.endpoint == \"firewall_rule_list\")) | length')\" = 1 ]"
check "list_tunnels with include_vps=1" "log_lines basic | jq -e 'select(.endpoint == \"list_tunnels\") | .form.include_vps == \"1\"' >/dev/null"

echo "firewall-audit.sh (Full Mesh on)"
: > "$LOG"
run linkall manage-firewall/scripts/firewall-audit.sh
check "exit 0" '[ "$RC" -eq 0 ]'
check "Full Mesh on" "printf '%s' \"\$OUT\" | grep -q '^Full Mesh: on.'"
check "per-tunnel inbound rule found" "printf '%s' \"\$OUT\" | grep -Eq '^alpha +on +TCP +internet +10\.2\.0\.2 +8443 +active +OPEN$'"
check "1 + one call per tunnel" "printf '%s' \"\$OUT\" | grep -q 'firewall_rule_list x3'"
check "per-tunnel calls sent tunnel_token in the body" "[ \"\$(log_lines linkall | jq -rs 'map(select(.endpoint == \"firewall_rule_list\") | .form.tunnel_token // empty) | join(\" \")')\" = 'SECRET-TT-A SECRET-TT-B' ]"

echo "leak detector canary (a doxx_call that puts params in curl's arguments)"
mkdir -p "$WORK/canary"
cp -R "$SKILLS/manage-firewall" "$WORK/canary/"
cat >> "$WORK/canary/manage-firewall/lib/doxx.sh" <<'EOF_CANARY'
# Canary: the old shape, params as curl arguments. The tests expect the leak
# detector to catch it.
doxx_call() {
  local ep="$1" kv args=()
  shift
  for kv in "$@"; do args+=(--data-urlencode "$kv"); done
  doxx__record "$ep"
  DOXX_OUT="$(doxx__token | curl -s -X POST "$DOXX_API_BASE" -d "$ep=1" ${args[@]+"${args[@]}"} --data-urlencode "token@-")"
}
EOF_CANARY
run_at "$WORK/canary" linkall manage-firewall/scripts/firewall-audit.sh
check "canary still runs (exit 0)" '[ "$RC" -eq 0 ]'
check "canary: the leak detector fails on a tunnel_token in curl's arguments" '! argv_clean'

echo "leak detector canary (a doxx_stats that puts the token header in curl's arguments)"
cp -R "$SKILLS/network-status" "$WORK/canary/"
cat >> "$WORK/canary/network-status/lib/doxx.sh" <<'EOF_CANARY'
# Canary: the token header as a curl argument. The tests expect the leak
# detector to catch it.
doxx_stats() {
  local ep="$1"
  shift
  doxx__record "stats/$ep"
  DOXX_OUT="$(curl -s -X POST "$DOXX_STATS_BASE/$ep" -H "X-Auth-Token: $(doxx__token)")"
}
EOF_CANARY
run_at "$WORK/canary" basic network-status/scripts/status-summary.sh
check "stats canary still runs (exit 0)" '[ "$RC" -eq 0 ]'
check "stats canary: the leak detector fails on the token in curl's arguments" '! argv_clean'

echo "firewall-audit.sh (Full Mesh on, a per-tunnel call fails)"
: > "$LOG"
run linkfail manage-firewall/scripts/firewall-audit.sh
check "exit 1 with the API message" "[ \"\$RC\" -eq 1 ] && printf '%s' \"\$OUT\" | grep -q '^doxx: firewall_rule_list: error: Tunnel not found or access denied$'"
check "stops at the first failing tunnel" "printf '%s' \"\$OUT\" | grep -q '^endpoints called: list_tunnels, firewall_rule_list x2$'"

echo "firewall-audit.sh (two tunnels with the same name)"
run dupnames manage-firewall/scripts/firewall-audit.sh
check "exit 0" '[ "$RC" -eq 0 ]'
check "each rule once, on its own tunnel" "[ \"\$(printf '%s' \"\$OUT\" | grep -Ec '^alpha +on +TCP')\" = 2 ] && printf '%s' \"\$OUT\" | grep -Eq ' 80 +active' && printf '%s' \"\$OUT\" | grep -Eq ' 443 +active'"

echo "snapshot.sh"
: > "$LOG"
run basic doxxnet/scripts/snapshot.sh
snap="$(printf '%s' "$OUT" | sed -n 's/^snapshot: //p')"
check "exit 0" '[ "$RC" -eq 0 ]'
check "file under XDG state dir" "case \"\$snap\" in '$WORK/home/.local/state/doxx/snapshots/'*.json) [ -f \"\$snap\" ] ;; *) false ;; esac"
check "file mode 600, dir mode 700" "[ \"\$(ls -l \"\$snap\" | cut -c1-10)\" = '-rw-------' ] && [ \"\$(ls -ld \"\$(dirname \"\$snap\")\" | cut -c1-10)\" = 'drwx------' ]"
check "counts line" "printf '%s' \"\$OUT\" | grep -q '^tunnels: 3, firewall rules: 5, Full Mesh: off, DNS configs: 3$'"
check "keeps tunnel_token, drops private_key" "jq -e '(.tunnels | all(has(\"tunnel_token\") and (has(\"private_key\") | not))) and (.firewall_rules | length == 5)' \"\$snap\" >/dev/null"
check "no private key anywhere in the file" "! grep -q 'SECRET-PK' \"\$snap\""
run basic doxxnet/scripts/snapshot.sh --no-dns
check "--no-dns skips the DNS call" "printf '%s' \"\$OUT\" | grep -q 'DNS configs: skipped' && ! printf '%s' \"\$OUT\" | grep -q dns_get_all_tunnel_configs"

echo "vps-wait.sh"
run basic manage-vps/scripts/vps-wait.sh web1 --interval 1 --timeout 60
check "exit 0 when running" '[ "$RC" -eq 0 ]'
check "prints each change once" "[ \"\$(printf '%s' \"\$OUT\" | grep -c 'web1: ')\" = 3 ] && printf '%s' \"\$OUT\" | grep -q 'web1: provisioning writing disk' && printf '%s' \"\$OUT\" | grep -q 'web1: running$'"
check "endpoints called" "printf '%s' \"\$OUT\" | grep -q '^endpoints called: vps_list, vps_get x4$'"
run basic manage-vps/scripts/vps-wait.sh nosuch --interval 1
check "unknown server: exit 1 with message" "[ \"\$RC\" -eq 1 ] && printf '%s' \"\$OUT\" | grep -q \"no single server named or with id 'nosuch'\""
run slow manage-vps/scripts/vps-wait.sh v123 --interval 1 --timeout 0
check "timeout: exit 3, state printed" "[ \"\$RC\" -eq 3 ] && printf %s \"\$OUT\" | grep -q \"web1: pending\" && printf %s \"\$OUT\" | grep -q \"still .pending. after 0s\""
run suspended manage-vps/scripts/vps-wait.sh web1 --interval 1
check "suspended: exit 1 with detail" "[ \"\$RC\" -eq 1 ] && printf '%s' \"\$OUT\" | grep -q 'web1 is suspended plan lapsed'"
check "default timeout is 100 s" "bash '$SKILLS/manage-vps/scripts/vps-wait.sh' --help | grep -q '(default 100'"
run basic manage-vps/scripts/vps-wait.sh web1 --timeout abc
check "bad --timeout: exit 2" '[ "$RC" -eq 2 ]'
run basic manage-vps/scripts/vps-wait.sh web1 --interval 0
check "--interval 0: exit 2" "[ \"\$RC\" -eq 2 ] && printf '%s' \"\$OUT\" | grep -q 'interval must be 1 or more'"
run slow manage-vps/scripts/vps-wait.sh v123 --interval 09 --timeout 08
check "--interval 09 --timeout 08 read as base 10, not octal" "[ \"\$RC\" -eq 3 ] && printf '%s' \"\$OUT\" | grep -q 'after 8s;' && ! printf '%s' \"\$OUT\" | grep -q 'value too great'"
run basic manage-vps/scripts/vps-wait.sh web1 --timeout=
check "empty --timeout: exit 2" "[ \"\$RC\" -eq 2 ] && printf '%s' \"\$OUT\" | grep -q 'whole seconds'"

echo "errors stop the script"
run err network-status/scripts/status-summary.sh
check "Config API error: exit 1, API message" "[ \"\$RC\" -eq 1 ] && printf '%s' \"\$OUT\" | grep -q '^doxx: list_tunnels: error: Invalid or expired token$'"
check "no Stats call after the error" "printf '%s' \"\$OUT\" | grep -q '^endpoints called: list_tunnels$'"
run staterr network-status/scripts/status-summary.sh
check "Stats plain-text 401: exit 1, HTTP code and text" "[ \"\$RC\" -eq 1 ] && printf '%s' \"\$OUT\" | grep -q '^doxx: stats/bandwidth: error (HTTP 401): Unauthorized'"
run err manage-vps/scripts/vps-wait.sh web1 --interval 1
check "vps_get error printed" "[ \"\$RC\" -eq 1 ] && printf '%s' \"\$OUT\" | grep -q '^doxx: vps_get: error: Server not found$'"
http_code() { "$REAL_CURL" -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$PORT/err/v1/" -d "$1=1" -d token=test-token; }
check "fake API: status error with HTTP 200 and with HTTP 404 (as the real API sends them)" \
  '[ "$(http_code list_tunnels)" = 200 ] && [ "$(http_code vps_get)" = 404 ]'
run unavail network-status/scripts/status-summary.sh
check "plain-text 503 (no JSON): exit 1 with the HTTP code" "[ \"\$RC\" -eq 1 ] && printf '%s' \"\$OUT\" | grep -q '^doxx: list_tunnels: unexpected answer (HTTP 503): <html>'"

echo "base URL overrides"
for bad in "https://evil.example/v1/" "https://evil.example/x.doxx.net/" "http://config.doxx.net/v1/" "https://a@b.doxx.net/"; do
  RC=0
  OUT="$(env -i PATH="$TEST_PATH" HOME="$WORK/home" DOXX_TOKEN=test-token DOXX_API_BASE="$bad" \
    bash "$SKILLS/network-status/scripts/status-summary.sh" 2>&1)" || RC=$?
  check "DOXX_API_BASE=$bad refused before any call" "[ \"\$RC\" -eq 1 ] && printf '%s' \"\$OUT\" | grep -q 'refusing to send the token' && ! printf '%s' \"\$OUT\" | grep -q 'endpoints called'"
done
RC=0
OUT="$(env -i PATH="$TEST_PATH" HOME="$WORK/home" DOXX_TOKEN=test-token DOXX_STATS_BASE="https://stats.evil.example/api/stats" \
  bash "$SKILLS/network-status/scripts/status-summary.sh" 2>&1)" || RC=$?
check "DOXX_STATS_BASE off doxx.net refused" "[ \"\$RC\" -eq 1 ] && printf '%s' \"\$OUT\" | grep -q 'DOXX_STATS_BASE must be'"
check "refused base: no token in output" no_secrets

echo "recipes from the generated skills: a line break in a value sends nothing"
# Each recipe line is taken from the generated text, pointed at the fake API,
# and run with values that hold a line break plus a second `url=` line. The
# config filter must refuse the whole config, so curl sends no request at all:
# not to the real URL, and not to the injected one. A normal value must work.
# The control swaps the filter for `cat` and must reach the injected URL, so
# the check cannot pass by never sending anything.
EVIL="http://127.0.0.1:$PORT/evil/v1/"
recipe() { # FILE PREFIX: the first line of FILE that starts with PREFIX, pointed at the fake API
  grep -m1 -F -- "$2" "$1" | sed \
    -e "s#https://config.doxx.net/v1/#http://127.0.0.1:$PORT/rcp/v1/#g" \
    -e "s#https://secure-wss.doxx.net/api/stats/ENDPOINT?PARAMS#http://127.0.0.1:$PORT/rcp/api/stats/alerts?last=session\\&tunnel_token=\$tt#"
}
run_recipe() { # LINE TT TOKEN: runs LINE (plus CALL) with $tt and DOXX_TOKEN set
  : > "$LOG"
  : > "$ARGV_LOG"
  env -i PATH="$TEST_PATH" HOME="$WORK/home" DOXX_TOKEN="$3" tt="$2" bash -c "$1${CALL:+; $CALL}" >/dev/null 2>&1 || true
}
no_requests() { [ ! -s "$LOG" ]; }
evil_untouched() { ! grep -q '"scenario": "evil"' "$LOG"; }
RECIPES=(
  "wireguard-qr (network-wizard)|$SKILLS/network-wizard/SKILL.md|r=\$(printf 'url=|form"
  "Stats recipe (network-stats)|$SKILLS/network-stats/SKILL.md|s=\$(printf 'header=|query"
  "doxx() helper (api/reference.md)|$REPO_ROOT/api/reference.md|doxx() {|form"
)
for entry in "${RECIPES[@]}"; do
  IFS='|' read -r label file prefix where <<<"$entry"
  line="$(recipe "$file" "$prefix")"
  CALL=""
  case "$label" in doxx*) CALL='doxx -d "wireguard=1&tunnel_token=$tt"' ;; esac
  check "$label: recipe found in the generated text" "[ -n \"\$line\" ]"
  run_recipe "$line" SECRET-TT-R test-token
  if [ "$where" = form ]; then
    check "$label: a normal value works (token and tunnel_token in the body)" "jq -se 'length == 1 and (.[0] | .token_ok and .form.tunnel_token == \"SECRET-TT-R\")' '$LOG' >/dev/null"
  else
    check "$label: a normal value works (token header, tunnel_token in the URL)" "jq -se 'length == 1 and (.[0] | .auth_header and .query.tunnel_token == \"SECRET-TT-R\")' '$LOG' >/dev/null"
  fi
  check "$label: no secret in a curl command line" argv_clean
  run_recipe "$line" "SECRET-TT-R
url=$EVIL" test-token
  check "$label: line break in tunnel_token: no request at all" 'no_requests && evil_untouched'
  run_recipe "$line" SECRET-TT-R "test-token
url=$EVIL"
  check "$label: line break in the token: no request at all" 'no_requests && evil_untouched'
  control="$(printf '%s' "$line" | sed 's/| awk -v n=.*}'"'"' | curl /| cat | curl /')"
  check "$label: control filter found" "[ \"\$control\" != \"\$line\" ]"
  run_recipe "$control" "SECRET-TT-R
url=$EVIL" test-token
  check "$label: control (no filter) does reach the injected URL" '! evil_untouched'
done

echo "every fixed-count config filter in src/ and api/ is the tested one, with the right line count (the doxx() helper computes n and is run above)"
filter_report="$(python3 - "$REPO_ROOT/src" "$REPO_ROOT/api/reference.md" <<'PY'
import os, re, sys
canon = None
bad = []
count = 0
files = [sys.argv[2]] + [os.path.join(d, f) for d, _, fs in os.walk(sys.argv[1]) for f in fs if f.endswith(".md")]
for path in files:
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        m = re.search(r"\| awk -v n=(\S+) ('[^']*') \|", line)
        if not m:
            continue
        count += 1
        canon = canon or m.group(2)
        fmt = re.search(r"printf '([^']*)'", line).group(1)
        want = str(fmt.count("\\n"))
        if m.group(2) != canon:
            bad.append(f"{path}:{n}: awk program differs")
        if m.group(1) != want:
            bad.append(f"{path}:{n}: n={m.group(1)}, printf writes {want} lines")
print(count)
print("\n".join(bad))
PY
)"
check "config filters found ($(printf '%s' "$filter_report" | head -1))" "[ \"\$(printf '%s' \"\$filter_report\" | head -1)\" -ge 8 ]"
check "all config filters identical, n matches the printf lines" "[ -z \"\$(printf '%s' \"\$filter_report\" | tail -n +2)\" ] || { printf '%s\\n' \"\$filter_report\" | tail -n +2; false; }"

echo "token handling"
RC=0
OUT="$(env -i PATH="$TEST_PATH" HOME="$WORK/empty-home" bash "$SKILLS/network-status/scripts/status-summary.sh" 2>&1)" || RC=$?
check "no token: exit 1 with guidance" "[ \"\$RC\" -eq 1 ] && printf '%s' \"\$OUT\" | grep -q 'no doxx.net token found'"
mkdir -p "$WORK/filehome/.config/doxxnet"
printf 'test-token\n' > "$WORK/filehome/.config/doxxnet/token"
RC=0
: > "$ARGV_LOG"
OUT="$(env -i PATH="$TEST_PATH" HOME="$WORK/filehome" \
  DOXX_API_BASE="http://127.0.0.1:$PORT/basic/v1/" DOXX_STATS_BASE="http://127.0.0.1:$PORT/basic/api/stats" \
  bash "$SKILLS/network-status/scripts/status-summary.sh" 2>&1)" || RC=$?
check "legacy ~/.config/doxxnet/token is read" '[ "$RC" -eq 0 ]'
check "legacy token file: no token or key in output" no_secrets
check "legacy token file: no token in a curl command line" argv_clean
printf 'test-token\nurl=%s\n' "$EVIL" > "$WORK/filehome/.config/doxxnet/token"
RC=0
: > "$LOG"
OUT="$(env -i PATH="$TEST_PATH" HOME="$WORK/filehome" \
  DOXX_API_BASE="http://127.0.0.1:$PORT/basic/v1/" DOXX_STATS_BASE="http://127.0.0.1:$PORT/basic/api/stats" \
  bash "$SKILLS/network-status/scripts/status-summary.sh" 2>&1)" || RC=$?
check "two-line token file: only the first line is the token (exit 0)" '[ "$RC" -eq 0 ]'
check "two-line token file: the injected URL got no request" evil_untouched
check "Config token sent in the form body" "jq -se 'map(select(.api == \"config\")) | all(.token_ok)' '$LOG' >/dev/null"

echo "api-drift-report.sh (tracking issue, with a fake gh)"
RB="$WORK/report"
mkdir -p "$RB/bin" "$RB/state"
cat > "$RB/bin/gh" <<'EOF_GH'
#!/usr/bin/env bash
# Fake gh for api-drift-report.sh: one optional open issue, #7, kept in $GH_STATE.
set -euo pipefail
printf '%s %s\n' "$1" "$2" >> "$GH_STATE/calls"
sub="$1 $2"; shift 2
title="" bodyfile=""
while [ $# -gt 0 ]; do
  case "$1" in
    --title) title="$2"; shift 2 ;;
    --body-file) bodyfile="$2"; shift 2 ;;
    *) shift ;;
  esac
done
case "$sub" in
  "issue list")
    if [ -f "$GH_STATE/title" ]; then jq -n --arg t "$(cat "$GH_STATE/title")" '[{number: 7, title: $t}]'; else echo '[]'; fi ;;
  "issue view") jq -Rs '{body: .}' < "$GH_STATE/body" ;;
  "issue create") printf '%s' "$title" > "$GH_STATE/title"; cp "$bodyfile" "$GH_STATE/body" ;;
  "issue edit") cp "$bodyfile" "$GH_STATE/body" ;;
  "issue close") rm -f "$GH_STATE/title" ;;
  "issue comment") : ;;
  *) echo "fake gh: unexpected $sub" >&2; exit 1 ;;
esac
EOF_GH
chmod +x "$RB/bin/gh"
printf 'manifest: x (version 1, 3 endpoints)\n\nMissing in reference (...):\n  new_one\n\ndrift found\n' > "$RB/drift1.txt"
printf 'manifest: x (version 1, 4 endpoints)\n\nMissing in reference (...):\n  new_one\n  new_two\n\ndrift found\n' > "$RB/drift2.txt"
printf 'manifest: x\nno drift\n' > "$RB/clean.txt"
report() {
  : > "$RB/state/calls"
  RC=0
  OUT="$(env PATH="$RB/bin:$PATH" GH_STATE="$RB/state" GITHUB_REPOSITORY=o/r GITHUB_RUN_ID=42 \
    bash "$REPO_ROOT/scripts/api-drift-report.sh" "$1" "$2" 2>&1)" || RC=$?
}
mutations() { grep -cE '^issue (create|edit|close|comment)' "$RB/state/calls" || true; }
report 0 "$RB/clean.txt"
check "no drift, no issue: no change" '[ "$RC" -eq 0 ] && [ "$(mutations)" = 0 ]'
report 1 "$RB/drift1.txt"
check "drift: opens the tracking issue" '[ "$RC" -eq 0 ] && grep -qx "issue create" "$RB/state/calls" && grep -q "^  new_one$" "$RB/state/body" && grep -q "api-drift-fingerprint: [0-9a-f]\{64\}" "$RB/state/body"'
report 1 "$RB/drift1.txt"
check "same drift next day: body refreshed, no comment" '[ "$RC" -eq 0 ] && grep -qx "issue edit" "$RB/state/calls" && ! grep -qx "issue comment" "$RB/state/calls" && ! grep -qx "issue create" "$RB/state/calls"'
report 1 "$RB/drift2.txt"
check "changed drift: body updated and one comment" '[ "$RC" -eq 0 ] && grep -qx "issue comment" "$RB/state/calls" && grep -q "^  new_two$" "$RB/state/body"'
report 2 "$RB/clean.txt"
check "manifest unreachable: issue left alone" '[ "$RC" -eq 0 ] && [ "$(mutations)" = 0 ] && [ -f "$RB/state/title" ]'
report 0 "$RB/clean.txt"
check "drift gone: closes the issue" '[ "$RC" -eq 0 ] && grep -qx "issue close" "$RB/state/calls" && [ ! -f "$RB/state/title" ]'
report 5 "$RB/clean.txt"
check "unexpected exit code: fails" '[ "$RC" -ne 0 ]'

echo
if [ "$FAILS" -eq 0 ]; then
  echo "tests: $PASSES passed"
else
  echo "tests: $FAILS failed, $PASSES passed"
  exit 1
fi

---
name: network-stats
description: "View doxx.net network stats: bandwidth usage, security alerts, threat categories, peak throughput"
version: 1.2.0
homepage: https://github.com/doxxcorp/doxx-skills
user-invocable: false
metadata:
  openclaw:
    requires:
      env: [DOXX_TOKEN]
      bins: [curl, jq]
    primaryEnv: DOXX_TOKEN
---

# doxx.net Network Stats

You help users view detailed bandwidth, security alert, and threat statistics for their doxx.net network.

User request: $ARGUMENTS

## Calling the API

The doxx.net Config API describes itself. Fetch the live manifest with `curl -s https://config.doxx.net/` (a GET, no token; it lists every endpoint with params, returns, auth and side effects): this file is a snapshot.

**Config API**: every call is `POST https://config.doxx.net/v1/`, form-encoded: the endpoint as `<endpoint>=1`, its params, and the account token as `token`. The token goes in through stdin (`--data-urlencode "token@-"`), so it is not in the curl command line either:

```
printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value" --data-urlencode "token@-"
```

- Responses are JSON with `status` set to `success` or `error`. HTTP 200 can still be an error: always check `status`.
- Every response carries a `context` field: what happened, what the params mean, what to do next. Read it before you guess.
- Pass values that may hold spaces or symbols (JSON, PEM, config text) with `--data-urlencode "name=value"`.
- Check `command -v jq` before the first read. If jq is missing, do not call reads whose answers carry secrets (`list_tunnels`, `user_list_tokens`, `vps_*`, Stats): without jq they cannot be filtered. Ask the user to install jq (`brew install jq` on macOS, `sudo apt install jq` on Debian/Ubuntu) first.

### The token

**Auth token: it never enters the AI conversation.**

The shell expands the token and pipes it into curl, so its value stays on this machine: it never appears in a tool call, in the curl arguments or in the process list. Use the `printf %s "..." | curl ... --data-urlencode "token@-"` form above exactly as written in every call (curl reads stdin only once, so every other param goes on the command line, except the secret params below). The expansion takes the first non-empty source of four, in this order:

1. `DOXX_TOKEN` env var: the user exports it before launching the agent.
2. `~/.config/doxx/token` file (skipped when empty or missing).
3. `DOXXNET_TOKEN` env var (legacy name, still read).
4. `~/.config/doxxnet/token` file (legacy path, still read).

The files are read with `grep -m1 -s .`, not `cat`: it prints only the first non-empty line, so a stray second line in the file never reaches curl, and it fails on an empty or missing file, so the next source is tried.

Never echo, print, `cat` or log the token on its own, and never write it into a file the user did not ask for.

`tunnel_token` values (from `list_tunnels` and others) are credentials too. Use them inside calls, but refer to tunnels by name when you talk to the user and never print a `tunnel_token`.

**Secret params** (`tunnel_token`, `target_token`, any other credential) must not go on the command line either: every user of the machine can read a command line in the process list. Send them with the token through stdin, as a curl config (`-K -`):

```
printf 'url=https://config.doxx.net/v1/\ndata-urlencode=token=%s\ndata-urlencode=tunnel_token=%s\n' "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" "$tt" | awk -v n=3 '{s = ""; for (i = 1; i <= length($0); i++) {c = substr($0, i, 1); s = s (c == "\\" || c == "\"" ? "\\" : "") c}; k = index(s, "="); o = o substr(s, 1, k - 1) " = \"" substr(s, k + 1) "\"\n"} END {if (NR == n) printf "%s", o}' | curl -s -K - -X POST -d "ENDPOINT=1&param=value"
```

The `printf` writes one `option=value` line per curl option, and the `awk` turns each line into `option = "value"` with `\` and `"` escaped, so a value cannot end its quotes. `n` is the number of lines the `printf` writes. If the count differs (a value that holds a line break would add a line, and with it a curl option of its own), the `awk` prints nothing: curl then has no URL and sends nothing at all. The URL is in the config for that reason. For each secret param, add one `data-urlencode=NAME=%s\n` line and one argument, and add 1 to `n` (here `$tt` is a shell variable that holds the tunnel's token). Params that are not secret stay in `-d`. Never type a token value into this command: let the shell fill it in from a variable.

**Check the token** (prints only the API answer, never the token; on success it includes the token's `role`):

```
printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "auth=1" --data-urlencode "token@-"
```

**No token, or the check fails:** ask the user to:

1. Create a token in the portal at https://app.doxx.net: Account > Auth Tokens, role **Network Admin**, expiry 7 to 30 days. Admin is needed only to manage tokens or billing.
2. Save it on this machine themselves, in their own terminal, with mode 0600. For example (the paste is not shown on screen):
   `mkdir -p ~/.config/doxx && (umask 077 && read -rs t && printf %s "$t" > ~/.config/doxx/token)`
   Or `read -rs DOXX_TOKEN && export DOXX_TOKEN` before starting the session (the paste is not shown and stays out of the shell history).

Pasting the token into the chat is the last resort. If the user pastes it anyway, do not repeat it in any reply, log or file name, and suggest a short expiry and revoking it when the session ends.

### MCP tools

If doxx MCP tools are available in this session (tool names equal endpoint names), you may call them instead of curl: the server injects the token. Everything else in this file (params, errors, rules) applies the same way.

**Stats API**: `POST https://secure-wss.doxx.net/api/stats/<endpoint>` (GET works too), token in the `X-Auth-Token` header. Params go in the query string, not the body. The header and the URL go to curl as a config on stdin (`-K -`, the same `awk` filter as for secret Config API params, with `n=2`), so neither the token nor a `tunnel_token` in the params is in the curl command line. Errors are plain text (401, 403, 400), not JSON.

Stats answers are keyed by `tunnel_token`: a top-level `tunnel_tokens` list, a `tunnel_token` on each row, and `by_tunnel` maps keyed by token. These are credentials. **Never print a Stats answer raw.** Always run it through this recipe, which fetches the tunnel names with `list_tunnels`, replaces every `tunnel_token` with a `tunnel` name (the summed rows become `all tunnels`; a name used by two tunnels becomes `NAME` and `NAME (2)`), renames the `by_tunnel` keys, and drops `tunnel_tokens`. Run it as one command, with `ENDPOINT?PARAMS` replaced and `FILTER` replaced by a jq filter that picks what to show (`.` shows the whole mapped answer):

```
s=$(printf 'header=X-Auth-Token: %s\nurl=%s\n' "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" "https://secure-wss.doxx.net/api/stats/ENDPOINT?PARAMS" | awk -v n=2 '{s = ""; for (i = 1; i <= length($0); i++) {c = substr($0, i, 1); s = s (c == "\\" || c == "\"" ? "\\" : "") c}; k = index(s, "="); o = o substr(s, 1, k - 1) " = \"" substr(s, k + 1) "\"\n"} END {if (NR == n) printf "%s", o}' | curl -s -K - -X POST)
printf %s "$s" | jq -e . >/dev/null 2>&1 || { echo "stats error: $s"; exit 1; }
t=$(printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "list_tunnels=1" --data-urlencode "token@-")
printf '%s\n%s' "$t" "$s" | jq -s '(reduce (.[0].tunnels // [] | .[] | select(.tunnel_token != null)) as $t ({m: {}, u: {}}; .u as $u | ($t.name // "unnamed tunnel") as $b | (if $u[$b] then first(range(2; infinite) | "\($b) (\(.))" | select($u[.] | not)) else $b end) as $k | .m[$t.tunnel_token] = $k | .u[$k] = true) | .m) as $n | .[1] | del(.tunnel_tokens) | walk(if type == "object" then (if has("tunnel_token") then .tunnel = (if .tunnel_token == "aggregate" then "all tunnels" else ($n[.tunnel_token // ""] // "unknown tunnel") end) | del(.tunnel_token) else . end) | (if (.by_tunnel | type) == "object" then .by_tunnel |= (to_entries | [foreach .[] as $e (0; if $n[$e.key] then . else . + 1 end; {key: ($n[$e.key] // "unknown tunnel \(.)"), value: $e.value})] | from_entries) else . end) else . end) | FILTER'
```

**One tunnel by name.** To look at one tunnel, filter the mapped answer on `.tunnel` (for example `FILTER` = `.data |= map(select(.tunnel == "NAME"))`) instead of putting its token in the URL: the API reads params only from the URL, so a `tunnel_token` there lands in server logs. Pass `tunnel_token` only where the API requires it (`alerts` with `last=session`). Resolve it by name inside the shell, never printing it, and put this before the recipe's first line, with `NAME` replaced and `PARAMS` containing `tunnel_token=$tt`:

```
tt=$(printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "list_tunnels=1" --data-urlencode "token@-" | jq -r --arg name "NAME" '[.tunnels[]? | select(.name == $name)] | if length == 1 then .[0].tunnel_token else empty end')
[ -n "$tt" ] || { echo "no single tunnel named NAME"; exit 1; }
```

The same two lines give `$tt` for any Config API call that needs a tunnel's token: pass it on stdin as a secret param (`data-urlencode=tunnel_token=%s`, see "Secret params" in "Calling the API"), never on the command line.

**Params per endpoint.** `bandwidth` takes `start` and `end` (RFC3339 in UTC, with `Z`), defaulting to the last hour; it has **no** `last` param. `alerts` takes `last` (`1m`, `1h`, `1d` or `24h`, `7d`, `30d`, `session`) or `start`/`end`, plus `type`. `summary` takes `days` (default 30).

Show the plain-text error to the user as given: 401 `Unauthorized` (bad or missing token), 403 `Forbidden: tunnel_token not owned by user`, 400 for a bad `last`, `start` or `end`.

Every Stats call below goes through the recipe above ("Never print a Stats answer raw"). In its output each row has a `tunnel` name instead of a `tunnel_token`, and `by_tunnel` is keyed by name. The `FILTER` values below assume that mapped shape.

## Stats API endpoints

### bandwidth

Throughput over time, in Mbps (peak per time bucket). Params: `start`, `end` (RFC3339 in UTC, for example `2026-11-17T08:00:00Z`; write `Z`, not `+00:00`, because a `+` breaks in a URL). Optional: `tunnel_token` (prefer filtering on `.tunnel`). With no `start`, it returns the last hour. There is no `last` and no `hours` param here. A start time 24 hours ago: `date -u -v-24H +%Y-%m-%dT%H:%M:%SZ` (macOS) or `date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ` (Linux).

The bucket size follows the range: 1s (up to 90 s), 1m (up to 2 h), 5m (up to 30 h), 1h (up to 8 days), 6h (longer). Data is kept for 30 days at most.

Returns `requested` (`start`, `end` as asked), `actual` (`start`, `end` unix times of the first and last data point; 0 when there is none), `granularity`, `data[]` (`tunnel_token`, `timestamp`, `peak_in`, `peak_out`, `samples`), `aggregate[]` (the same, summed over all tunnels), `tunnel_tokens`.

Peaks per tunnel: `ENDPOINT?PARAMS` = `bandwidth` (last hour) or `bandwidth?start=...&end=...`, and

```
{granularity, requested, per_tunnel: ((.data // []) | group_by(.tunnel) | map({tunnel: .[0].tunnel, peak_in: (map(.peak_in) | max), peak_out: (map(.peak_out) | max)})), total_peak_in: ((.aggregate // []) | map(.peak_in) | max), total_peak_out: ((.aggregate // []) | map(.peak_out) | max)}
```

### alerts

Security alerts and DNS blocks. Optional params: `last` (`1m`, `1h`, `1d` or `24h`, `7d`, `30d`, or `session`), or `start` (with optional `end`, RFC3339 UTC) instead of `last`; `type` (one event type); `tunnel_token`. With no time params it covers the last 24 hours.

- With `last=session`, `tunnel_token` is required (without it: 400). Resolve it by name with the `tt=` lines of the recipe and use `PARAMS` = `last=session&tunnel_token=$tt`; the token is never printed. It counts from the start of the doxx.net app's Live Activity session on that tunnel (iOS), so the numbers match the app. With no such session it returns zero counts.
- The `type` param is the event type, for example `dns_block` or `security_event`. For a security event, the row's `value` says what it was (for example `dangerous_port`, `port_scan`, `dns_bypass`, `doh_bypass`).

Returns `start`, `end`, `granularity`, `block_count` (all events counted in the range), `category_counts` (DNS block categories such as `ads`, `tracking`, `malware`, `other`; every security event rolls up into `security`), `totals` (count per event type), `data[]` sorted by count (`tunnel_token`, `prefix`, `type`, `action` (for DNS events: what the resolver does with that domain now, `block` or `allow`), `value`, `category`, `count`, `last_seen`), `tunnel_tokens`. With `last=session` also `session_start` and `is_session`. Non-existent-domain and service-discovery lookups are left out.

`FILTER` for the top 20:

```
{start, end, block_count, category_counts, totals, top: [(.data // [])[:20][] | {tunnel, type, value, category, action, count, last_seen}]}
```

### summary

Peak bandwidth and alert totals for a period. Optional: `days` (default 30; data older than 30 days is gone), `tunnel_token`.

Returns `days`, `bandwidth` (`total_peak_in`, `total_peak_out`: the highest single-tunnel peak in Mbps, not a sum; `total_samples`; `by_tunnel`: `peak_in`, `peak_out` keyed by `tunnel_token`), `alerts` (count per event type), `tunnel_tokens`.

`FILTER`:

```
{days, alerts, total_peak_in: .bandwidth.total_peak_in, total_peak_out: .bandwidth.total_peak_out, by_tunnel: .bandwidth.by_tunnel}
```

### global (no auth)

The global count of threats blocked across all doxx.net users.

```
curl -s "https://secure-wss.doxx.net/api/stats/global"
```

Returns `status`, `total`, `ts`.

### Cloud servers

`bandwidth`, `alerts` and `summary` cover tunnels only. A cloud server's gauges (CPU, memory, disk, network) come from `/api/stats/vps` (optional: `tunnel_token`, `start`, `end`, `latest_only=1`). Use the `manage-vps` skill for cloud servers.

## Config API endpoints (for context)

- `list_tunnels`: tunnel names for the recipe's token-to-name map. Its output also holds keys: never print it raw.

## Common requests

**"Full overview" / "Show me everything":** global total, bandwidth for the last hour, alerts for the last 24 hours (`last=1d`) with categories, and a 7-day summary (`days=7`). Run each through the recipe and present a short dashboard table with tunnel names.

**"Show my bandwidth":** bandwidth for the last hour, peaks per tunnel and in total, in Mbps.

**"What's being blocked?":** alerts with `last=1d`; lead with `category_counts` and the top blocked domains.

**"Show security alerts":** alerts with `type=security_event`; group the rows by `value` (`dangerous_port`, `port_scan` and the rest).

**"Since I connected" / "this session":** the recipe's `tt=` lines with the tunnel's name, then alerts with `PARAMS` = `last=session&tunnel_token=$tt`. Explain that "session" means the app's Live Activity session.

**"Give me a summary":** summary with `days=30`: peak bandwidth per tunnel and alert totals.

**"How many threats has doxx blocked?":** global, format the total.

## Time ranges

- "just now" / "last minute" → alerts `last=1m`, bandwidth `start` 60 seconds ago (1-second buckets)
- "last hour" → alerts `last=1h`, bandwidth with no `start`
- "today" / "past day" → alerts `last=1d`, bandwidth `start` 24 hours ago
- "this week" → alerts `last=7d`, summary `days=7`
- "this month" → alerts `last=30d`, summary `days=30`
- A specific range → `start` and `end` (RFC3339 UTC)

## Guidelines

- Present data in tables or short summaries, with tunnel names, never tunnel tokens.
- Bandwidth values are peaks in Mbps, not transferred volume: do not add them up into GB.
- Group alerts by category and point out anything unusual (port scans, bypass attempts, a sudden spike).
- If the user has several tunnels, offer one tunnel (filter by name) or all of them.

# doxx.net Network Status

You help users monitor their doxx.net network: tunnel and device status, the network this machine is on, bandwidth, and security alerts.


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

## Batching calls (Code Mode)

For work that needs many reads, run one short program that makes the calls, joins and filters the answers in the shell, and prints only the summary. The conversation gets a few lines instead of raw JSON, the result is the same every time, and secrets such as `tunnel_token` never leave the shell.

**When to batch:**

- Three or more calls feed one answer (for example tunnels, stats and alerts for a status overview).
- A fan-out: the same call once per tunnel or per server.
- A large answer you need only a few fields from.
- Polling: waiting for a state to change.

**When to make single calls:** one question that one or two reads answer.

**Writes:**

- A single write is always one call, after the user confirms, with its `status` and `context` checked before the next call. A failure then never leaves a half-applied change.
- A bulk write (the same change on many tunnels) may run in a script, but the script must first print the planned calls as a dry run (endpoint, tunnel name and values, never a token). Show that plan to the user, and run it with `--apply` only after a clear yes. It still makes the calls one at a time and stops at the first error.

**Prefer the bundled scripts.** Some skills ship ready scripts in a `scripts/` directory, with their shared helper in `lib/`. `<skill dir>` below means the skill's root directory: the one that holds its `SKILL.md` (or `AGENTS.md`) and the `scripts/` and `lib/` directories. Run a script with `bash <skill dir>/scripts/<name>.sh`; each one takes `--help`, is read-only unless it says otherwise, and prints the endpoints it called. Write your own bash + curl + jq script only when no bundled script fits, and follow the same rules:

- Check `command -v jq` first: the scripts need `jq`. Without it, do not batch: make single calls, and none whose answer carries secrets (see "Calling the API").
- If `<skill dir>/lib/doxx.sh` exists, source it instead of writing curl calls by hand. `doxx_require` checks curl, jq and the token, and prints the endpoints called when the script ends. `doxx_call ENDPOINT key=value ...` (Config API) and `doxx_stats ENDPOINT key=value ...` (Stats API) put the answer in `$DOXX_OUT`, stop on an error with the API's message, and keep the auth token out of every command line. `doxx_names "$tunnels" "$answer" FILTER` maps tokens to tunnel names.
- Never print the auth token or a `tunnel_token`. Map tokens to tunnel names inside the script; if a token must be shown at all, show only its first 4 characters and "…".
- Make the calls one after another, never in parallel, and respect the rate limits (`network_info`: 30 calls a minute per account).
- Stop at the first error and print the API's `message` (Stats errors are plain text).
- At the end, print the list of endpoints the script called, so the user sees what ran.

## Config API endpoints

- `list_tunnels`: tunnel status (`is_connected`, `connection_status`, `assigned_ip`, `server`). The output also holds each tunnel's `tunnel_token` and WireGuard `private_key`: show only the fields you need, for example `jq '.tunnels[] | {name, server, assigned_ip, is_connected, connection_status}'`.
- `device_list_unified`: devices with `is_online`, `last_seen`, `tunnel_count` and seat state (see the `manage-devices` skill).
- `device_status`: is one device still registered to this account. Params: `device_id_hash` (a device's `device_hash`). Returns `registered`, `seated`, `tunnels` (count). Read-only.
- `network_info`: what this machine's network looks like from doxx.net: `ip` (the public address this request came from), `family` (`ipv4` or `ipv6`), `asn` and `org` (the ISP; left out for a private or unknown address), `node`, `ts`, `history` (always `none`). doxx.net answers it from its own database, asks no outside service, and keeps no record of the call.
  - Call it once when the user asks or when the network changes, never on a timer: the limit is 30 calls a minute per account (then 429).
  - The answer is the address this request left from. When this machine's internet traffic runs through a doxx.net tunnel, `org` usually shows doxx.net, not the home ISP.
- `firewall_rule_list`: firewall rules (rows carry a `tunnel_token`: do not print it). With Full Mesh on, call it per `tunnel_token` (without one, `rules` is `null`); `rules` is `null` whenever empty, so read `.rules // []`.
- `firewall_link_all_status`: is Full Mesh on.
- `dns_blocklist_stats`: per-blocklist details (domain counts, categories). Needs the token.

## Stats API endpoints

Run every Stats call through the recipe above ("Never print a Stats answer raw"); response fields and ready-made `FILTER` values are in the `network-stats` skill. In short:

- bandwidth: params `start`, `end` (RFC3339 UTC); with no `start`, the last hour. No `last`, no `hours`.
- alerts: `last` (`1m`, `1h`, `1d` or `24h`, `7d`, `30d`, `session`), or `start`/`end`; `type`; with no time params, the last 24 hours. `last=session` needs `tunnel_token` (resolve it by name with the recipe's `tt=` lines), else 400.
- summary: `days` (default 30).
- global: no auth.


## Common requests

**"Show me everything":** tunnels (names, connected or not), devices online, Full Mesh on or off, then alerts for the last 24 hours (`alerts?last=1d`) and bandwidth for the last hour (`bandwidth`), each through the Stats recipe so only tunnel names are printed. Run the reads in one short script (see "Batching calls"), printing only selected fields.

**Fast path:** `bash <skill dir>/scripts/status-summary.sh --last 1d` prints one table by tunnel name (server, address, connected, peak Mbps in and out, alert count) plus the alert totals by category and the top alerts, in three calls (`list_tunnels`, Stats `bandwidth`, Stats `alerts`). `--last` takes `1m`, `1h` (default), `1d`, `24h`, `7d` or `30d`. Add `device_list_unified` and `firewall_link_all_status` if the user wants devices and Full Mesh too.

**"Is my tunnel working?":** `list_tunnels` (`is_connected`, `connection_status`), then on this machine `dig A doxx.net @10.10.10.10 +short` (the tunnel's resolver answers only through the tunnel).

**"What network am I on?" / "What is my IP?" / "Who is my ISP?":** `network_info`, once.

**"Is my old phone still on the account?":** find its `device_hash` in `device_list_unified`, then `device_status`.

**"What's being blocked?":** alerts with `type=dns_block` through the Stats recipe, plus `dns_blocklist_stats` for what each list covers.

**"How much bandwidth am I using?":** bandwidth through the Stats recipe (last hour, or a `start`/`end` range): peak Mbps per tunnel name.

## Guidelines

- Present data in a clear, readable format: tables or short summaries, with tunnel and device names.
- Bandwidth figures are peak throughput in Mbps, not volume.
- For alerts, group by category and highlight anything unusual (port scans, bypass attempts, spikes).
- Never print tunnel tokens, private keys or auth tokens; name tunnels and devices instead.

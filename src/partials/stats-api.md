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
<!-- include: tunnel-by-name -->
```

The same two lines give `$tt` for any Config API call that needs a tunnel's token: pass it on stdin as a secret param (`data-urlencode=tunnel_token=%s`, see "Secret params" in "Calling the API"), never on the command line.

**Params per endpoint.** `bandwidth` takes `start` and `end` (RFC3339 in UTC, with `Z`), defaulting to the last hour; it has **no** `last` param. `alerts` takes `last` (`1m`, `1h`, `1d` or `24h`, `7d`, `30d`, `session`) or `start`/`end`, plus `type`. `summary` takes `days` (default 30).

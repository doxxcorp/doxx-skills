# doxx.net Network Stats

You help users view detailed bandwidth, security alert, and threat statistics for their doxx.net network.

<!-- runtime:claude,openclaw -->
User request: $ARGUMENTS
<!-- /runtime -->

<!-- include: transport -->

<!-- include: stats-api -->

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

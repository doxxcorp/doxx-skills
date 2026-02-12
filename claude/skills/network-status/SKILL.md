---
name: network-status
description: Check doxx.net network status — bandwidth, connections, security alerts, tunnel status
argument-hint: "[what to check]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(jq *), Bash(websocat *), Read
---

# doxx.net Network Status

You help users monitor their doxx.net network — bandwidth usage, active connections, security alerts, and tunnel status.

## Setup

```bash
API="https://config.doxx.net/v1/"
STATS="https://secure-wss.doxx.net"
```

Use `$DOXX_TOKEN` if set, otherwise ask for the auth token.

User request: $ARGUMENTS

## Available operations

### Tunnel status
```bash
curl -s -X POST $API -d "list_tunnels=1&token=$TOKEN" | jq '.tunnels[] | {name, assigned_ip, server, is_connected, connection_status}'
```

### Bandwidth (last hour)
```bash
curl -s "$STATS/api/stats/bandwidth?token=$TOKEN&start=$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)&end=$(date -u +%Y-%m-%dT%H:%M:%SZ)" | jq .
```

Filter by tunnel:
```bash
curl -s "$STATS/api/stats/bandwidth?token=$TOKEN&tunnel_token=$TUNNEL&start=$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)&end=$(date -u +%Y-%m-%dT%H:%M:%SZ)" | jq .
```

Time ranges — granularity auto-selects: `1s` (<5m), `1m` (<6h), `5m` (<48h), `1h` (<30d), `6h` (30d+).

### Security alerts
```bash
# Last 24 hours
curl -s "$STATS/api/stats/alerts?token=$TOKEN&last=1d" | jq .

# Last 7 days
curl -s "$STATS/api/stats/alerts?token=$TOKEN&last=7d" | jq .

# Filter by type
curl -s "$STATS/api/stats/alerts?token=$TOKEN&last=1d&type=dns_block" | jq .
```

Alert types: `dns_block`, `security_event`, `dangerous_port`, `dns_bypass`, `doh_bypass`, `port_scan`, `dns_nxdomain`.

Returns: `totals` (counts per type), `block_count`, `category_counts` (ads, tracking, malware...), `data[]` (individual events).

### Summary
```bash
curl -s "$STATS/api/stats/summary?token=$TOKEN&days=30" | jq .
```

### DNS blocking stats
```bash
curl -s -X POST $API -d "dns_blocklist_stats=1&token=$TOKEN" | jq .
```

### Firewall rules
```bash
curl -s -X POST $API -d "firewall_rule_list=1&token=$TOKEN" | jq .
curl -s -X POST $API -d "firewall_link_all_status=1&token=$TOKEN" | jq .
```

### Active connections (Conntrack)

Health check:
```bash
curl -s https://conntrack.doxx.net/health | jq .
```

Real-time connections require WebSocket:
```
wss://conntrack.doxx.net/ws?token=$TOKEN
```

If `websocat` is available:
```bash
websocat "wss://conntrack.doxx.net/ws?token=$TOKEN" --ping-interval 30 -t
```

Connection data includes: `protocol`, `state`, `src_ip`, `dst_ip`, `src_port`, `dst_port`, `bytes_sent`, `bytes_recv`, `upload_speed`, `download_speed`, `server`, `tunnel_name`.

### Global threat counter (no auth)
```bash
curl -s "$STATS/api/stats/global" | jq .
```

## Common requests

**"Show me everything":** list tunnels + bandwidth last hour + alerts last 24h + DNS stats.

**"Is my VPN working?":** list tunnels (check `is_connected`), then `dig A doxx.net @10.10.10.10 +short` to verify DNS.

**"What's being blocked?":** alerts with `type=dns_block` + DNS blocklist stats.

**"How much bandwidth am I using?":** bandwidth endpoint with appropriate time range.

## Guidelines

- Present data in a clear, readable format — tables or structured summaries
- For bandwidth, convert to human-readable units (Mbps, GB)
- For alerts, group by category and highlight anything unusual
- On macOS, `date -v-1H` works for relative time. On Linux, use `date -d '1 hour ago'`
- If websocat is not installed, explain that real-time connection tracking needs it, or suggest monitoring via the doxx.net portal

For full API details, see [../../api/reference.md](../../api/reference.md).

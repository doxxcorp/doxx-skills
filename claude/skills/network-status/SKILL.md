---
name: network-status
description: Check doxx.net network status: bandwidth, connections, security alerts, tunnel status
argument-hint: "[what to check]"
user-invocable: true
allowed-tools: Bash(python3 *), Bash(websocat *), Bash(dig *), Read
---

# doxx.net Network Status

You help users monitor their doxx.net network:bandwidth usage, active connections, security alerts, and tunnel status.

## Setup

All Config API calls use the helper script. Locate it first:
```bash
DOXXNET_API=$(find ~/.claude/plugins -name "doxx-api.py" -path "*/doxxnet/*" 2>/dev/null | head -1)
```

Stats API calls use Python directly (GET requests to a different endpoint).

If `$DOXXNET_TOKEN` is not set in the environment, ask the user for their auth token.

User request: $ARGUMENTS

## Available operations

### Tunnel status
```bash
python3 $DOXXNET_API list_tunnels
```

### Bandwidth (last hour)
```bash
python3 -c "
import urllib.request, json, os
from datetime import datetime, timedelta, timezone
token = os.environ['DOXXNET_TOKEN']
now = datetime.now(timezone.utc)
start = (now - timedelta(hours=1)).strftime('%Y-%m-%dT%H:%M:%SZ')
end = now.strftime('%Y-%m-%dT%H:%M:%SZ')
url = f'https://secure-wss.doxx.net/api/stats/bandwidth?token={token}&start={start}&end={end}'
resp = urllib.request.urlopen(url)
print(json.dumps(json.loads(resp.read()), indent=2))
"
```

Filter by tunnel — add `&tunnel_token=TUNNEL` to the URL.

Time ranges:granularity auto-selects: `1s` (<5m), `1m` (<6h), `5m` (<48h), `1h` (<30d), `6h` (30d+).

### Security alerts
```bash
python3 -c "
import urllib.request, json, os
token = os.environ['DOXXNET_TOKEN']
url = f'https://secure-wss.doxx.net/api/stats/alerts?token={token}&last=1d'
resp = urllib.request.urlopen(url)
print(json.dumps(json.loads(resp.read()), indent=2))
"
```

Change `last=1d` to `last=7d` for weekly, or add `&type=dns_block` to filter.

Alert types: `dns_block`, `security_event`, `dangerous_port`, `dns_bypass`, `doh_bypass`, `port_scan`, `dns_nxdomain`.

Returns: `totals` (counts per type), `block_count`, `category_counts` (ads, tracking, malware...), `data[]` (individual events).

### Summary
```bash
python3 -c "
import urllib.request, json, os
token = os.environ['DOXXNET_TOKEN']
url = f'https://secure-wss.doxx.net/api/stats/summary?token={token}&days=30'
resp = urllib.request.urlopen(url)
print(json.dumps(json.loads(resp.read()), indent=2))
"
```

### DNS blocking stats
```bash
python3 $DOXXNET_API dns_blocklist_stats
```

### Firewall rules
```bash
python3 $DOXXNET_API firewall_rule_list
python3 $DOXXNET_API firewall_link_all_status
```

### Active connections (Conntrack)

Health check:
```bash
python3 -c "
import urllib.request, json
resp = urllib.request.urlopen('https://conntrack.doxx.net/health')
print(json.dumps(json.loads(resp.read()), indent=2))
"
```

Real-time connections require WebSocket:
```
wss://conntrack.doxx.net/ws?token=$TOKEN
```

If `websocat` is available:
```bash
websocat "wss://conntrack.doxx.net/ws?token=$DOXXNET_TOKEN" --ping-interval 30 -t
```

Connection data includes: `protocol`, `state`, `src_ip`, `dst_ip`, `src_port`, `dst_port`, `bytes_sent`, `bytes_recv`, `upload_speed`, `download_speed`, `server`, `tunnel_name`.

### Global threat counter (no auth)
```bash
python3 -c "
import urllib.request, json
resp = urllib.request.urlopen('https://secure-wss.doxx.net/api/stats/global')
print(json.dumps(json.loads(resp.read()), indent=2))
"
```

## Common requests

**"Show me everything":** list tunnels + bandwidth last hour + alerts last 24h + DNS stats.

**"Is my tunnel working?":** list tunnels (check `is_connected`), then `dig A doxx.net @10.10.10.10 +short` to verify DNS.

**"What's being blocked?":** alerts with `type=dns_block` + DNS blocklist stats.

**"How much bandwidth am I using?":** bandwidth endpoint with appropriate time range.

## Guidelines

- Present data in a clear, readable format:tables or structured summaries
- For bandwidth, convert to human-readable units (Mbps, GB)
- For alerts, group by category and highlight anything unusual
- If websocat is not installed, explain that real-time connection tracking needs it, or suggest monitoring via the doxx.net portal

For full API details, see [../../../api/reference.md](../../../api/reference.md).

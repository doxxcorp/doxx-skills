---
name: network-status
description: Check doxx.net network status: bandwidth, connections, security alerts, tunnel status
argument-hint: "[what to check]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(cat *), Bash(dig *), Bash(mkdir *), Bash(chmod *), Read, Write
---

# doxx.net Network Status

You help users monitor their doxx.net network: bandwidth usage, active connections, security alerts, and tunnel status.

User request: $ARGUMENTS

## API convention

Token file: `~/.config/doxxnet/token`. If missing or auth fails, ask the user for their token, validate with `auth=1&token=THEIR_TOKEN`, and save it:
```
mkdir -p ~/.config/doxxnet && printf '%s\n' 'TOKEN' > ~/.config/doxxnet/token && chmod 600 ~/.config/doxxnet/token
```

**Config API** — POST to `https://config.doxx.net/v1/`:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=$(cat ~/.config/doxxnet/token)"
```

**Stats API** — GET from `https://secure-wss.doxx.net/api/stats/`:
```
curl -s "https://secure-wss.doxx.net/api/stats/ENDPOINT?token=$(cat ~/.config/doxxnet/token)&param=value"
```

## Config API endpoints

- `list_tunnels` — tunnel status (check `is_connected`)
- `firewall_rule_list` — firewall rules
- `firewall_link_all_status` — mesh networking status
- `dns_blocklist_stats` — DNS blocklist statistics (no auth)

## Stats API endpoints

- `bandwidth` — bandwidth stats. Optional: `tunnel_token`, `start` (ISO 8601), `end`, `hours` (default: 1)
- `alerts` — security alerts. Optional: `tunnel_token`, `last` (session/1m/1h/1d/7d/30d, default: 1d), `type`
- `summary` — network summary. Optional: `days` (default: 30)
- `global` — global threat counter (no auth)

## Alert types

`dns_block`, `security_event`, `dangerous_port`, `dns_bypass`, `doh_bypass`, `port_scan`, `dns_nxdomain`

## Common requests

**"Show me everything":** list tunnels + bandwidth + alerts + DNS stats

**"Is my tunnel working?":** list tunnels (check `is_connected`), verify with `dig A doxx.net @10.10.10.10 +short`

**"What's being blocked?":** alerts with type=dns_block + DNS blocklist stats

**"How much bandwidth am I using?":** stats/bandwidth with appropriate hours parameter

## Guidelines

- Present data in a clear, readable format — tables or structured summaries
- For bandwidth, convert to human-readable units (Mbps, GB)
- For alerts, group by category and highlight anything unusual
- Suggest investigating anomalies (unusual bandwidth spikes, port scans)

---
name: network-status
description: Check doxx.net network status: bandwidth, connections, security alerts, tunnel status
argument-hint: "[what to check]"
user-invocable: true
allowed-tools: Bash(dig *)
---

# doxx.net Network Status

You help users monitor their doxx.net network: bandwidth usage, active connections, security alerts, and tunnel status.

Use the doxxnet MCP tools for all API calls. If the token is not configured, ask the user for their auth token.

User request: $ARGUMENTS

## Available MCP tools

- `doxx_list_tunnels` — tunnel status (check `is_connected`)
- `doxx_bandwidth` — bandwidth stats (default: last hour, optional: hours, tunnel_token)
- `doxx_alerts` — security alerts (default: last 1d, optional: last, type, tunnel_token)
- `doxx_summary` — network summary (optional: days, default 30)
- `doxx_global_stats` — global threat counter (no auth)
- `doxx_dns_blocklist_stats` — DNS blocklist statistics
- `doxx_firewall_list` — firewall rules
- `doxx_firewall_link_status` — mesh networking status

## Alert types

`dns_block`, `security_event`, `dangerous_port`, `dns_bypass`, `doh_bypass`, `port_scan`, `dns_nxdomain`

## Common requests

**"Show me everything":** list tunnels + bandwidth + alerts + DNS stats

**"Is my tunnel working?":** list tunnels (check `is_connected`), verify with `dig A doxx.net @10.10.10.10 +short`

**"What's being blocked?":** alerts with type=dns_block + DNS blocklist stats

**"How much bandwidth am I using?":** bandwidth tool with appropriate hours parameter

## Guidelines

- Present data in a clear, readable format — tables or structured summaries
- For bandwidth, convert to human-readable units (Mbps, GB)
- For alerts, group by category and highlight anything unusual
- Suggest investigating anomalies (unusual bandwidth spikes, port scans)

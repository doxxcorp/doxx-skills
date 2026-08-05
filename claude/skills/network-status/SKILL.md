---
name: network-status
description: "Check doxx.net network status: bandwidth, connections, security alerts, tunnel status"
argument-hint: "[what to check]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(cat *), Bash(dig *), Read, Write
---

# doxx.net Network Status

> **Live schema first.** The doxx.net Config API is agent-descriptive. Fetch `https://config.doxx.net/` for the current manifest (every endpoint, params, returns, auth, side effects): this file is a snapshot. Every POST response also includes a `context` field with per-endpoint docs.

You help users monitor their doxx.net network: bandwidth usage, active connections, security alerts, and tunnel status.

User request: $ARGUMENTS

## API convention

**IMPORTANT: token security -- must never enter the AI conversation.**

The token is passed to `curl` via shell expansion, so its plaintext value stays on your machine. Two sources, checked in this order:

1. `$DOXXNET_TOKEN` env var (preferred, zero exposure): the user exports it before launching Claude Code. curl commands below reference it as `$DOXXNET_TOKEN`; the shell expands it at exec time, so the actual value is never emitted in a tool call.
2. `$(cat ~/.config/doxxnet/token)` inline subshell fallback if the env var is unset (same shell-expansion property: the value never enters the assistant's context).

Never use the `Read` tool on `~/.config/doxxnet/token`: doing so would load the plaintext into the AI conversation and ship it to Anthropic on every subsequent tool call. `Write` is fine to save a token the user just pasted (one-time exposure). Bash is used only for `curl` commands and inline `cat` fallback.

If `$DOXXNET_TOKEN` is unset and no token file exists, ask the user to either `export DOXXNET_TOKEN=your-token` in their shell (zero exposure, restart the session) or paste the token here to save to `~/.config/doxxnet/token` (one-time exposure, then future sessions use the subshell fallback). Validate with `curl -s -X POST https://config.doxx.net/v1/ -d "auth=1&token=$DOXXNET_TOKEN"` (or substitute `$(cat ~/.config/doxxnet/token)` if using the file).

**Config API**: POST to `https://config.doxx.net/v1/`:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=$DOXXNET_TOKEN"
```

**Stats API**: POST to `https://secure-wss.doxx.net/api/stats/` with `X-Auth-Token` header:
```
curl -s -X POST https://secure-wss.doxx.net/api/stats/ENDPOINT -H "X-Auth-Token: $DOXXNET_TOKEN" -d "param=value"
```

The `$DOXXNET_TOKEN` shown in curl examples is expanded by the shell at exec time. If the env var is unset, substitute `$(cat ~/.config/doxxnet/token)` inline within the curl args instead. Never inline the plaintext token value into a tool call.

## Config API endpoints

- `list_tunnels`: tunnel status (check `is_connected`)
- `firewall_rule_list`: firewall rules
- `firewall_link_all_status`: mesh networking status
- `dns_blocklist_stats`: DNS blocklist statistics (no auth)

## Stats API endpoints

- `bandwidth`: bandwidth stats. Optional: `tunnel_token`, `start` (ISO 8601), `end`, `hours` (default: 1)
- `alerts`: security alerts. Optional: `tunnel_token`, `last` (session/1m/1h/1d/7d/30d, default: 1d), `type`
- `summary`: network summary. Optional: `days` (default: 30)
- `global`: global threat counter (no auth)

## Alert types

`dns_block`, `security_event`, `dangerous_port`, `dns_bypass`, `doh_bypass`, `port_scan`, `dns_nxdomain`

## Common requests

**"Show me everything":** list tunnels + bandwidth + alerts + DNS stats

**"Is my tunnel working?":** list tunnels (check `is_connected`), verify with `dig A doxx.net @10.10.10.10 +short`

**"What's being blocked?":** alerts with type=dns_block + DNS blocklist stats

**"How much bandwidth am I using?":** stats/bandwidth with appropriate hours parameter

## Guidelines

- Present data in a clear, readable format: tables or structured summaries
- For bandwidth, convert to human-readable units (Mbps, GB)
- For alerts, group by category and highlight anything unusual
- Suggest investigating anomalies (unusual bandwidth spikes, port scans)

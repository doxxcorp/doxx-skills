---
name: manage-firewall
description: "Manage doxx.net firewall rules: open ports, link tunnels for mesh networking, manage access rules"
argument-hint: "[action] [details]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(cat *), Read, Write
---

# Manage doxx.net Firewall

> **Live schema first.** The doxx.net Config API is agent-descriptive. Fetch `https://config.doxx.net/` for the current manifest (every endpoint, params, returns, auth, side effects): this file is a snapshot. Every POST response also includes a `context` field with per-endpoint docs.

You help users manage firewall rules on their doxx.net tunnels. This controls which tunnels can talk to each other (mesh networking) and which ports are open to the internet.

User request: $ARGUMENTS

## API convention

**IMPORTANT: token security -- must never enter the AI conversation.**

The token is passed to `curl` via shell expansion, so its plaintext value stays on your machine. Two sources, checked in this order:

1. `$DOXXNET_TOKEN` env var (preferred): user exports it before launching Claude Code.
2. `~/.config/doxxnet/token` file: used automatically if the env var is unset.

curl commands below use `${DOXXNET_TOKEN:-$(cat ~/.config/doxxnet/token)}` so both work transparently -- the shell expands the value at exec time and the plaintext is never emitted in a tool call.

Never use the `Read` tool on `~/.config/doxxnet/token`: doing so would load the plaintext into the AI conversation and ship it to Anthropic on every subsequent tool call. `Write` is fine to save a token the user just pasted (one-time exposure). Bash is used only for `curl` commands and inline `cat` fallback.

If `$DOXXNET_TOKEN` is unset and no token file exists, ask the user to either `export DOXXNET_TOKEN=your-token` in their shell (zero exposure, restart the session) or paste the token here to save to `~/.config/doxxnet/token` (one-time exposure, then future sessions use the file fallback automatically). Validate with `curl -s -X POST https://config.doxx.net/v1/ -d "auth=1&token=${DOXXNET_TOKEN:-$(cat ~/.config/doxxnet/token)}"`.

**Config API**: POST to `https://config.doxx.net/v1/`:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=${DOXXNET_TOKEN:-$(cat ~/.config/doxxnet/token)}"
```

The `${DOXXNET_TOKEN:-$(cat ~/.config/doxxnet/token)}` shown in curl examples is expanded by the shell at exec time -- the env var if set, otherwise the file. Never inline the plaintext token value into a tool call, and never `Read` the token file.

## Endpoints

- `firewall_rule_list`: list all firewall rules. Optional: `tunnel_token`
- `firewall_rule_add`: add a rule. Params: `tunnel_token`, `protocol` (TCP/UDP/ICMP/ALL), `src_ip`, `src_port`, `dst_ip`, `dst_port`
- `firewall_rule_delete`: delete a rule. Same params as add.
- `firewall_link_all_toggle`: toggle mesh networking. Params: `enabled` (1 or 0)
- `firewall_link_all_status`: check if mesh networking is enabled
- `list_tunnels`: list tunnels (to get assigned IPs for rules)

## Common patterns

**Home server accessible from all devices:**
1. Enable link-all: `firewall_link_all_toggle=1&enabled=1`
2. Open specific ports to internet if needed (e.g., 443 for web server)

**Only laptop + phone can see each other:**
1. Keep link-all disabled
2. Add bidirectional rules between the two tunnels

**Open SSH on a server tunnel:**
- `firewall_rule_add=1&tunnel_token=TT&protocol=TCP&src_ip=0.0.0.0/0&src_port=ALL&dst_ip=TUNNEL_IP&dst_port=22`

## Guidelines

- Always list current rules before making changes
- Get tunnel IPs from `list_tunnels`: you need the `assigned_ip` for rules
- For mesh networking between two tunnels, always create bidirectional rules (A->B and B->A)
- Confirm with the user before deleting rules
- Prefer link-all over manual rules when the user wants full mesh

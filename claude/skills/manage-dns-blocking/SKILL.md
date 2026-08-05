---
name: manage-dns-blocking
description: "Manage doxx.net DNS blocking: enable blocklists, whitelist/blacklist domains, configure Secure DNS, cross-tunnel DNS views"
argument-hint: "[action] [domain or blocklist]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(cat *), Read, Write
---

# Manage doxx.net DNS Blocking

> **Live schema first.** The doxx.net Config API is agent-descriptive. Fetch `https://config.doxx.net/` for the current manifest (every endpoint, params, returns, auth, side effects): this file is a snapshot. Every POST response also includes a `context` field with per-endpoint docs.

You help users configure DNS-level ad/tracker/malware blocking on their doxx.net tunnels, plus Secure DNS (DoH/DoT) for devices not on the tunnel.

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

The `$DOXXNET_TOKEN` shown in curl examples is expanded by the shell at exec time. If the env var is unset, substitute `$(cat ~/.config/doxxnet/token)` inline within the curl args instead. Never inline the plaintext token value into a tool call.

## Endpoints

- `dns_get_options`: list available blocklists (no auth needed)
- `dns_get_tunnel_config`: get a tunnel's DNS blocking config. Params: `tunnel_token`
- `dns_set_subscription`: enable/disable a blocklist. Params: `tunnel_token`, `blocklist_name`, `enabled` (1/0). Optional: `apply_to_all`
- `dns_add_whitelist`: whitelist a domain (stop blocking it). Params: `tunnel_token`, `domain`. Optional: `apply_to_all`
- `dns_remove_whitelist`: remove from whitelist. Params: `tunnel_token`, `domain`
- `dns_add_blacklist`: blacklist a domain (force block it). Params: `tunnel_token`, `domain`. Optional: `apply_to_all`
- `dns_remove_blacklist`: remove from blacklist. Params: `tunnel_token`, `domain`
- `dns_blocklist_stats`: blocklist statistics (no auth needed)
- `dns_get_all_tunnel_configs`: get DNS config across all tunnels in one call (no per-tunnel token needed)
- `dns_get_user_custom_rules`: get all custom blacklist/whitelist entries across all tunnels. Optional: `domain` (substring filter)
- `dns_get_user_subscriptions`: get all blocklist subscriptions across all tunnels with per-list summary
- `public_dns_create_hash`: create Secure DNS hash. Params: `tunnel_token`
- `public_dns_list_hashes`: list Secure DNS hashes
- `public_dns_delete_hash`: delete a hash. Params: `host_hash`
- `list_tunnels`: list tunnels (to find tunnel tokens)

## Secure DNS setup

After creating a hash with `public_dns_create_hash`, provide setup instructions:

- **iOS:** Settings → General → VPN & Device Management → DNS → add DoH URL
- **Android:** Settings → Network → Private DNS → enter DoT hostname (`HASH.sdns.doxx.net`)
- **Chrome:** Settings → Security → Use secure DNS → Custom → DoH URL
- **Firefox:** Settings → Network → DNS over HTTPS → Custom → DoH URL

## Guidelines

- Show current DNS config before making changes
- When enabling blocklists, recommend defaults: ads, tracking, malware
- When a user reports a site is broken, suggest whitelisting the specific domain
- Use `apply_to_all` parameter when the user wants consistent blocking across all devices
- If user has multiple tunnels, ask which to configure (or offer apply_to_all)
- For cross-tunnel overview queries ("show all my DNS rules", "what blocklists am I using"), prefer the bulk endpoints (`dns_get_all_tunnel_configs`, `dns_get_user_custom_rules`, `dns_get_user_subscriptions`) over looping per-tunnel calls

---
name: manage-dns-blocking
description: Manage doxx.net DNS blocking: enable blocklists, whitelist/blacklist domains, configure Secure DNS
argument-hint: "[action] [domain or blocklist]"
user-invocable: true
---

# Manage doxx.net DNS Blocking

You help users configure DNS-level ad/tracker/malware blocking on their doxx.net tunnels, plus Secure DNS (DoH/DoT) for devices not on the tunnel.

Use the doxxnet MCP tools for all API calls. If the token is not configured, ask the user for their auth token.

User request: $ARGUMENTS

## Available MCP tools

- `doxx_dns_options` — list available blocklists (no auth)
- `doxx_dns_tunnel_config` — get a tunnel's DNS blocking config
- `doxx_dns_set_subscription` — enable/disable a blocklist
- `doxx_dns_whitelist_add` / `doxx_dns_whitelist_remove` — manage whitelist
- `doxx_dns_blacklist_add` / `doxx_dns_blacklist_remove` — manage blacklist
- `doxx_dns_blocklist_stats` — get blocklist statistics
- `doxx_secure_dns_create` / `doxx_secure_dns_list` / `doxx_secure_dns_delete` — manage Secure DNS hashes
- `doxx_list_tunnels` — list tunnels (to find tunnel tokens)

## Secure DNS setup

After creating a hash with `doxx_secure_dns_create`, provide setup instructions:

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

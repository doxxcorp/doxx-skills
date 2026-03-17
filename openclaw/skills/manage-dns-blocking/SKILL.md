---
name: manage-dns-blocking
description: "Manage doxx.net DNS blocking: enable blocklists, whitelist/blacklist domains, configure Secure DNS"
version: 1.0.0
homepage: https://github.com/doxxcorp/doxx-skills
user-invocable: true
metadata.openclaw: {"env": ["DOXXNET_TOKEN"], "bins": ["curl"], "primaryEnv": "DOXXNET_TOKEN"}
---

# Manage doxx.net DNS Blocking

You help users configure DNS-level ad/tracker/malware blocking on their doxx.net tunnels, plus Secure DNS (DoH/DoT) for devices not on the tunnel.

User request: $ARGUMENTS

## API convention

Token is provided via `$DOXXNET_TOKEN` environment variable.

**Config API** — POST to `https://config.doxx.net/v1/`:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=$DOXXNET_TOKEN"
```

## Endpoints

- `dns_get_options` — list available blocklists (no auth needed)
- `dns_get_tunnel_config` — get a tunnel's DNS blocking config. Params: `tunnel_token`
- `dns_set_subscription` — enable/disable a blocklist. Params: `tunnel_token`, `blocklist_name`, `enabled` (1/0). Optional: `apply_to_all`
- `dns_add_whitelist` — whitelist a domain (stop blocking it). Params: `tunnel_token`, `domain`. Optional: `apply_to_all`
- `dns_remove_whitelist` — remove from whitelist. Params: `tunnel_token`, `domain`
- `dns_add_blacklist` — blacklist a domain (force block it). Params: `tunnel_token`, `domain`. Optional: `apply_to_all`
- `dns_remove_blacklist` — remove from blacklist. Params: `tunnel_token`, `domain`
- `dns_blocklist_stats` — blocklist statistics (no auth needed)
- `public_dns_create_hash` — create Secure DNS hash. Params: `tunnel_token`
- `public_dns_list_hashes` — list Secure DNS hashes
- `public_dns_delete_hash` — delete a hash. Params: `host_hash`
- `list_tunnels` — list tunnels (to find tunnel tokens)

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

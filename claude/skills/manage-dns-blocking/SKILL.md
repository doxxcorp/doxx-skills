---
name: manage-dns-blocking
description: Manage doxx.net DNS blocking — enable blocklists, whitelist/blacklist domains, configure Secure DNS
argument-hint: "[action] [domain or blocklist]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(jq *), Read
---

# Manage doxx.net DNS Blocking

You help users configure DNS-level ad/tracker/malware blocking on their doxx.net tunnels, plus Secure DNS (DoH/DoT) for non-VPN devices.

## Setup

```bash
API="https://config.doxx.net/v1/"
```

Use `$DOXX_TOKEN` if set, otherwise ask for the auth token.

User request: $ARGUMENTS

## Available operations

### List available blocklists (no auth)
```bash
curl -s -X POST $API -d "dns_get_options=1" | jq '.options[] | {name, display_name, description, category, domain_count, default_enabled}'
```

### Get tunnel's DNS config
```bash
curl -s -X POST $API -d "dns_get_tunnel_config=1&token=$TOKEN&tunnel_token=$TUNNEL" | jq .
```

Returns: `dns_blocking_enabled`, `base_protections[]`, `subscriptions[]`, `whitelists[]`, `blacklists[]`.

### Enable/disable a blocklist
```bash
# Enable
curl -s -X POST $API -d "dns_set_subscription=1&token=$TOKEN&tunnel_token=$TUNNEL&subscription=BLOCKLIST_NAME&enabled=1"

# Disable
curl -s -X POST $API -d "dns_set_subscription=1&token=$TOKEN&tunnel_token=$TUNNEL&subscription=BLOCKLIST_NAME&enabled=0"

# Apply to ALL tunnels
curl -s -X POST $API -d "dns_set_subscription=1&token=$TOKEN&tunnel_token=$TUNNEL&subscription=BLOCKLIST_NAME&enabled=1&apply_to_all=1"
```

### Whitelist a domain (stop blocking it)
```bash
curl -s -X POST $API -d "dns_add_whitelist=1&token=$TOKEN&tunnel_token=$TUNNEL&domain=example.com"

# Apply to all tunnels
curl -s -X POST $API -d "dns_add_whitelist=1&token=$TOKEN&tunnel_token=$TUNNEL&domain=example.com&apply_to_all=1"
```

### Remove from whitelist
```bash
curl -s -X POST $API -d "dns_remove_whitelist=1&token=$TOKEN&tunnel_token=$TUNNEL&domain=example.com"
```

### Blacklist a domain (force block it)
```bash
curl -s -X POST $API -d "dns_add_blacklist=1&token=$TOKEN&tunnel_token=$TUNNEL&domain=evil.com"

# Apply to all tunnels
curl -s -X POST $API -d "dns_add_blacklist=1&token=$TOKEN&tunnel_token=$TUNNEL&domain=evil.com&apply_to_all=1"
```

### Remove from blacklist
```bash
curl -s -X POST $API -d "dns_remove_blacklist=1&token=$TOKEN&tunnel_token=$TUNNEL&domain=evil.com"
```

### Get blocklist stats
```bash
curl -s -X POST $API -d "dns_blocklist_stats=1&token=$TOKEN" | jq .
```

Returns: `total_domains`, `lists[]` with per-list domain counts and status.

### Secure DNS (DoH/DoT for non-VPN devices)

Create a personalized DNS hash:
```bash
curl -s -X POST $API -d "public_dns_create_hash=1&token=$TOKEN&tunnel_token=$TUNNEL" | jq .
```

Returns `doh_url` and `dot_host`. Use these to get your tunnel's DNS blocking on any device without VPN:

- **iOS:** Settings → General → VPN & Device Management → DNS → add DoH URL
- **Android:** Settings → Network → Private DNS → enter DoT hostname (`HASH.sdns.doxx.net`)
- **Chrome:** Settings → Security → Use secure DNS → Custom → DoH URL
- **Firefox:** Settings → Network → DNS over HTTPS → Custom → DoH URL

List existing hashes:
```bash
curl -s -X POST $API -d "public_dns_list_hashes=1&token=$TOKEN" | jq .hashes
```

Delete a hash:
```bash
curl -s -X POST $API -d "public_dns_delete_hash=1&token=$TOKEN&host_hash=HASH"
```

## Guidelines

- Show current DNS config before making changes
- When enabling blocklists, recommend defaults: ads, tracking, malware
- When a user reports a site is broken, suggest whitelisting the specific domain
- Use `apply_to_all=1` when the user wants consistent blocking across all devices
- If user has multiple tunnels, ask which to configure (or offer apply_to_all)

For full API details, see [../../../api/reference.md](../../../api/reference.md).

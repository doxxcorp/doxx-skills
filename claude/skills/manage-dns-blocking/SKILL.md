---
name: manage-dns-blocking
description: Manage doxx.net DNS blocking: enable blocklists, whitelist/blacklist domains, configure Secure DNS
argument-hint: "[action] [domain or blocklist]"
user-invocable: true
allowed-tools: Bash(python3 *), Read
---

# Manage doxx.net DNS Blocking

You help users configure DNS-level ad/tracker/malware blocking on their doxx.net tunnels, plus Secure DNS (DoH/DoT) for devices not on the tunnel.

If `$DOXXNET_TOKEN` is not set in the environment, ask the user for their auth token.

User request: $ARGUMENTS

## Available operations

### List available blocklists (no auth)
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py dns_get_options
```

### Get tunnel's DNS config
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py dns_get_tunnel_config tunnel_token=TUNNEL
```

Returns: `dns_blocking_enabled`, `base_protections[]`, `subscriptions[]`, `whitelists[]`, `blacklists[]`.

### Enable/disable a blocklist
```bash
# Enable
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py dns_set_subscription tunnel_token=TUNNEL subscription=BLOCKLIST_NAME enabled=1

# Disable
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py dns_set_subscription tunnel_token=TUNNEL subscription=BLOCKLIST_NAME enabled=0

# Apply to ALL tunnels
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py dns_set_subscription tunnel_token=TUNNEL subscription=BLOCKLIST_NAME enabled=1 apply_to_all=1
```

### Whitelist a domain (stop blocking it)
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py dns_add_whitelist tunnel_token=TUNNEL domain=example.com

# Apply to all tunnels
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py dns_add_whitelist tunnel_token=TUNNEL domain=example.com apply_to_all=1
```

### Remove from whitelist
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py dns_remove_whitelist tunnel_token=TUNNEL domain=example.com
```

### Blacklist a domain (force block it)
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py dns_add_blacklist tunnel_token=TUNNEL domain=evil.com

# Apply to all tunnels
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py dns_add_blacklist tunnel_token=TUNNEL domain=evil.com apply_to_all=1
```

### Remove from blacklist
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py dns_remove_blacklist tunnel_token=TUNNEL domain=evil.com
```

### Get blocklist stats
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py dns_blocklist_stats
```

Returns: `total_domains`, `lists[]` with per-list domain counts and status.

### Secure DNS (DoH/DoT for devices not on the tunnel)

Create a personalized DNS hash:
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py public_dns_create_hash tunnel_token=TUNNEL
```

Returns `doh_url` and `dot_host`. Use these to get your tunnel's DNS blocking on any device without an encrypted tunnel:

- **iOS:** Settings → General → VPN & Device Management → DNS → add DoH URL
- **Android:** Settings → Network → Private DNS → enter DoT hostname (`HASH.sdns.doxx.net`)
- **Chrome:** Settings → Security → Use secure DNS → Custom → DoH URL
- **Firefox:** Settings → Network → DNS over HTTPS → Custom → DoH URL

List existing hashes:
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py public_dns_list_hashes
```

Delete a hash:
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py public_dns_delete_hash host_hash=HASH
```

## Guidelines

- Show current DNS config before making changes
- When enabling blocklists, recommend defaults: ads, tracking, malware
- When a user reports a site is broken, suggest whitelisting the specific domain
- Use `apply_to_all=1` when the user wants consistent blocking across all devices
- If user has multiple tunnels, ask which to configure (or offer apply_to_all)

For full API details, see [../../../api/reference.md](../../../api/reference.md).

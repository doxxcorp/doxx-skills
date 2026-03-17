---
name: doxxnet
description: "Manage your doxx.net private network: tunnels, devices, firewall, domains, DNS blocking, IP addresses, profiles, account settings, bandwidth stats, and security alerts"
version: 1.0.0
homepage: https://github.com/doxxcorp/doxx-skills
user-invocable: true
metadata.openclaw: {"env": ["DOXXNET_TOKEN"], "bins": ["curl", "openssl", "dig", "wg-quick"], "primaryEnv": "DOXXNET_TOKEN"}
---

# doxx.net

You help users manage all aspects of their doxx.net private network. Determine which API endpoints to call based on their request.

User request: $ARGUMENTS

## API convention

Token is provided via `$DOXXNET_TOKEN` environment variable. All curl commands use it directly.

**Config API** — POST to `https://config.doxx.net/v1/`:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=$DOXXNET_TOKEN"
```

**Stats API** — POST to `https://secure-wss.doxx.net/api/stats/` with `X-Auth-Token` header:
```
curl -s -X POST https://secure-wss.doxx.net/api/stats/ENDPOINT -H "X-Auth-Token: $DOXXNET_TOKEN" -d "param=value"
```

**Special responses:** `sign_certificate` returns raw PEM (not JSON). `generate_qr` returns binary PNG — use `curl -s ... -o file.png`.

Always check the `status` field in JSON responses — HTTP 200 can still be an error.

## Tunnels

- `list_tunnels` — list all tunnels with IPs, servers, connection status
- `create_tunnel` — params: `server` (required), `name`
- `create_tunnel_mobile` — params: `server`, `name`, `device_type` (mobile/web)
- `update_tunnel` — params: `tunnel_token` (required), `name`, `server`, `firewall`, `ipv6_enabled`, `block_bad_dns`
- `delete_tunnel` — params: `tunnel_token` (permanent, confirm first)
- `wireguard` — get WireGuard config. Params: `tunnel_token`
- `disconnect_peer` — force-disconnect. Params: `tunnel_token`
- `servers` — list available servers (no auth)
- `generate_qr` — QR code (binary PNG, no auth). Params: `data`, optional: `size`. Use `-o file.png`

WireGuard config format:
```
[Interface]
PrivateKey = {private_key}
Address = {address}
DNS = {dns}

[Peer]
PublicKey = {public_key}
AllowedIPs = {allowed_ips}
Endpoint = {endpoint}
PersistentKeepalive = 25
```
macOS: write to `/etc/wireguard/doxx.conf`, run `sudo wg-quick up doxx`. iOS/Android: generate QR, scan in WireGuard app.

## Firewall

- `firewall_rule_list` — list rules. Optional: `tunnel_token`
- `firewall_rule_add` — params: `tunnel_token`, `protocol` (TCP/UDP/ICMP/ALL), `src_ip`, `src_port`, `dst_ip`, `dst_port`
- `firewall_rule_delete` — same params as add
- `firewall_link_all_toggle` — mesh networking on/off. Params: `enabled` (1/0)
- `firewall_link_all_status` — check mesh status

For mesh between two tunnels, create bidirectional rules (A->B and B->A). Prefer link-all for full mesh.

## Domains & DNS

- `list_domains`, `create_domain` (params: `domain`), `delete_domain`
- `list_dns` (params: `domain`), `create_dns_record`, `update_dns_record`, `delete_dns_record`
  - Record params: `domain`, `name` (FQDN), `type` (A/AAAA/CNAME/MX/TXT/NS/SRV/PTR), `content`. Optional: `ttl`, `prio`
- `get_domain_validation` — TXT code for external domain import
- `import_domain` — import after TXT verification
- `sign_certificate` — sign a CSR (returns raw PEM). Params: `domain`, `csr`

Popular TLDs: `.lan`, `.vpn`, `.mesh`, `.home`, `.wg`, `.doxx`. Default is `.doxx`.

TLS workflow: `openssl ecparam -genkey -name prime256v1 -o D.key` → `openssl req -new -key D.key -out D.csr -subj "/CN=D"` → `sign_certificate`

## DNS Blocking

- `dns_get_options` — list available blocklists (no auth)
- `dns_get_tunnel_config` — current blocking config. Params: `tunnel_token`
- `dns_set_subscription` — enable/disable blocklist. Params: `tunnel_token`, `blocklist_name`, `enabled` (1/0). Optional: `apply_to_all`
- `dns_add_whitelist` / `dns_remove_whitelist` — params: `tunnel_token`, `domain`. Optional: `apply_to_all`
- `dns_add_blacklist` / `dns_remove_blacklist` — params: `tunnel_token`, `domain`. Optional: `apply_to_all`
- `dns_blocklist_stats` — blocklist statistics (no auth)

**Secure DNS (DoH/DoT)** for devices not on the tunnel:
- `public_dns_create_hash` — create hash. Params: `tunnel_token`
- `public_dns_list_hashes` / `public_dns_delete_hash` (params: `host_hash`)

## Devices

- `device_list_unified` — list all devices with subscription info and guest accounts. Returns: `my_devices[]`, `guest_accounts[]`, `subscription`
- `device_rename` — rename or change icon. Params: `device_hash`, `device_name`. Optional: `device_icon`
- `device_delete` — permanently delete device (removes tunnels, IPs, seats). Params: `target_device_hash`

DeviceInfo fields: device_hash, device_name, device_model, os_type, device_type, device_icon, is_current, is_online, last_seen, tunnel_count, has_seat, is_owner, can_remove, can_rename, can_delete

## IP Addresses

- `list_addresses` — list assigned IPs with type, location, tunnel, profile, connection status
- `assign_address` — assign IP to profile. Params: `address`, `type`. Optional: `profile_id`
- `release_address` — release IP. Params: `address`, `type`
- `rotate_address` — rotate to new IP. Params: `address`, `type`
- `lease_public_ipv4` — lease dedicated public IPv4. Params: `profile_name`, `profile_icon`, `profile_type`, `server`. Optional: `ip_type`, `include_ipv6`

## Saved Profiles

- `list_saved_profiles` — list profiles with settings and usage status
- `create_saved_profile` — create. Params: `profile_name`, `profile_icon`, `profile_type`, `server`
- `rename_saved_config` — rename. Params: `profile_id`, `profile_name`
- `update_saved_profile` — update. Params: `profile_id`, and: `profile_icon`, `profile_name`, `preferred_server`
- `delete_saved_profile` — delete. Params: `profile_id`
- `load_profile` — apply profile to tunnel. Params: `tunnel_token`, `profile_id`

## Account

- `get_profile` — get recovery email/phone, notification preferences, recovery code count
- `update_profile` — update. Params: `recovery_email`, `recovery_phone`, `notifications`
- `create_account_recovery` — generate recovery codes. Returns: `codes[]`
- `subscription_status` — check subscription tier, status, pro features

## Stats

- `bandwidth` — usage over time. Params: `start`, `end` (ISO 8601), optional: `tunnel_token`
  ```
  curl -s -X POST https://secure-wss.doxx.net/api/stats/bandwidth -H "X-Auth-Token: $DOXXNET_TOKEN" -d "start=ISO8601&end=ISO8601"
  ```
  Returns: `data[]` with `peak_in`/`peak_out` (Mbps), `aggregate[]`

- `alerts` — security alerts and DNS blocks. Params: `last` (session/1m/1h/1d/7d/30d), optional: `tunnel_token`, `type`
  ```
  curl -s -X POST https://secure-wss.doxx.net/api/stats/alerts -H "X-Auth-Token: $DOXXNET_TOKEN" -d "last=1d"
  ```
  Returns: `totals`, `block_count`, `category_counts` (ads, tracking, malware), `data[]`

- `summary` — peak bandwidth + alert totals. Params: `days` (default: 30), optional: `tunnel_token`
  ```
  curl -s -X POST https://secure-wss.doxx.net/api/stats/summary -H "X-Auth-Token: $DOXXNET_TOKEN" -d "days=30"
  ```

- `global` — global threat counter (no auth, GET only)
  ```
  curl -s "https://secure-wss.doxx.net/api/stats/global"
  ```

Alert types: `dns_block`, `security_event`, `dangerous_port`, `dns_bypass`, `doh_bypass`, `port_scan`, `dns_nxdomain`

Time range shortcuts: "last hour" → `last=1h`, "today" → `last=1d`, "this week" → `last=7d`, "this month" → `last=30d`

## Guidelines

- Always list current state before making changes (`list_tunnels`, `list_domains`, `firewall_rule_list`)
- Call `list_tunnels` when you need tunnel names, IPs, or tokens
- Call `device_list_unified` when you need device info
- Call `list_addresses` for IP address queries
- Call `list_saved_profiles` for profile queries
- Confirm before device deletion and address release
- Confirm with user before destructive operations (delete tunnel, delete domain)
- Present stats in clear tables — convert bandwidth to Mbps, group alerts by category
- For multi-tunnel users, offer to filter by tunnel or show all
- When the request spans multiple areas, make all relevant API calls and present a unified answer

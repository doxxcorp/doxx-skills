# doxx.net API Reference (Agent-Optimized)

All Config API calls use `POST https://config.doxx.net/v1/` with `application/x-www-form-urlencoded`. Endpoint is selected by `endpoint_name=1` parameter.

**Failover endpoints:** `config-us-east.doxx.net`, `config-us-west.doxx.net`, `config-eu-central.doxx.net` (same `/v1/` path).

**Auth:** Most endpoints require `token=AUTH_TOKEN`. Exceptions noted with "(no auth)".

**Responses:** JSON with `"status": "success"` or `"status": "error"`. HTTP 200 can still be an error — always check `status` field.

**Variables used below:**
```
API="https://config.doxx.net/v1/"
TOKEN="your_auth_token"
TUNNEL="your_tunnel_token"
```

---

## Account

### auth
Validate a token.
```bash
curl -s -X POST $API -d "auth=1&token=$TOKEN"
```
Returns: `{"status": "success", "message": "Authentication successful"}`

### tos_status
```bash
curl -s -X POST $API -d "tos_status=1&token=$TOKEN"
```
Returns: `{"status": "success", "tos_accepted": true, "accepted_at": "...", "version": "1.0"}`

### accept_tos
```bash
curl -s -X POST $API -d "accept_tos=1&token=$TOKEN"
```

### get_profile
```bash
curl -s -X POST $API -d "get_profile=1&token=$TOKEN"
```
Returns: `profile` object with `recovery_email`, `recovery_phone`, `created_at`, `updated_at` + `recovery_codes_count`.

### update_profile
```bash
curl -s -X POST $API -d "update_profile=1&token=$TOKEN&email=EMAIL&name=NAME"
```
Optional params: `email`, `name`.

### create_account_recovery
Generate recovery codes (save these — they're the only way to recover a lost token).
```bash
curl -s -X POST $API -d "create_account_recovery=1&token=$TOKEN"
```
Returns: `codes` array, `set_id`, `created_at`.

### verify_account_recovery
Recover account with a recovery code. Returns a new auth token.
```bash
curl -s -X POST $API -d "verify_account_recovery=1&recovery_code=CODE"
```
Returns: `new_token`, `user_id`.

### delete_account
```bash
curl -s -X POST $API -d "delete_account=1&token=$TOKEN"
```

### merge_account
Merge all tunnels/settings from `source_token` into `token`.
```bash
curl -s -X POST $API -d "merge_account=1&token=$TOKEN&source_token=SOURCE_TOKEN"
```
Returns: `new_token`, `merged_tunnels`, `merged_whitelist`, `merged_blacklist`.

---

## Servers

### servers (no auth)
```bash
curl -s -X POST $API -d "servers=1"
```
Returns: `servers[]` with `server_name`, `location`, `description`, `continent`, `public_key`, `best_for`, `operator`.

Server names are hostnames like `wireguard.mia.us.doxx.net`. Use these in `create_tunnel`.

---

## Tunnels

### list_tunnels
```bash
curl -s -X POST $API -d "list_tunnels=1&token=$TOKEN"
```
Returns: `tunnels[]` with `tunnel_token`, `name`, `server`, `assigned_ip`, `assigned_v6`, `public_key`, `private_key`, `is_connected`, `connection_status`, `firewall`, `ipv6_enabled`, `block_bad_dns`.

### create_tunnel
```bash
curl -s -X POST $API -d "create_tunnel=1&token=$TOKEN&name=NAME&server=SERVER_HOSTNAME"
```
Required: `server`. Optional: `name`.

### create_tunnel_mobile
```bash
curl -s -X POST $API -d "create_tunnel_mobile=1&token=$TOKEN&server=SERVER_HOSTNAME&device_type=mobile"
```
Optional: `device_hash`, `device_type` (`mobile`, `desktop`, `server`, `web`).
Returns: `tunnel_token`, `assigned_ip`, `assigned_v6`, `public_key`, `private_key`.

### update_tunnel
```bash
curl -s -X POST $API -d "update_tunnel=1&token=$TOKEN&tunnel_token=$TUNNEL&name=NEW_NAME"
```
Optional: `name`, `server`, `firewall` (1/0), `ipv6_enabled` (1/0), `block_bad_dns` (1/0).

### delete_tunnel
```bash
curl -s -X POST $API -d "delete_tunnel=1&token=$TOKEN&tunnel_token=$TUNNEL"
```

### wireguard
Get WireGuard config for a tunnel.
```bash
curl -s -X POST $API -d "wireguard=1&token=$TOKEN&tunnel_token=$TUNNEL"
```
Returns: `config.interface` (`private_key`, `address`, `dns`) + `config.peer` (`public_key`, `allowed_ips`, `endpoint`, `persistent_keepalive`).

### disconnect_peer
```bash
curl -s -X POST $API -d "disconnect_peer=1&token=$TOKEN&tunnel_token=$TUNNEL"
```

---

## DNS Blocking

### dns_get_options (no auth)
List available blocklists.
```bash
curl -s -X POST $API -d "dns_get_options=1"
```
Returns: `options[]` with `name`, `display_name`, `description`, `category`, `domain_count`, `default_enabled`.

### dns_get_tunnel_config
```bash
curl -s -X POST $API -d "dns_get_tunnel_config=1&token=$TOKEN&tunnel_token=$TUNNEL"
```
Returns: `dns_blocking_enabled`, `base_protections[]`, `subscriptions[]`, `whitelists[]`, `blacklists[]`.

### dns_set_subscription
```bash
curl -s -X POST $API -d "dns_set_subscription=1&token=$TOKEN&tunnel_token=$TUNNEL&subscription=ads&enabled=1"
```
Optional: `apply_to_all=1` to apply to all tunnels.

### dns_add_whitelist
```bash
curl -s -X POST $API -d "dns_add_whitelist=1&token=$TOKEN&tunnel_token=$TUNNEL&domain=example.com"
```
Optional: `apply_to_all=1`.

### dns_remove_whitelist
```bash
curl -s -X POST $API -d "dns_remove_whitelist=1&token=$TOKEN&tunnel_token=$TUNNEL&domain=example.com"
```

### dns_add_blacklist
```bash
curl -s -X POST $API -d "dns_add_blacklist=1&token=$TOKEN&tunnel_token=$TUNNEL&domain=evil.com"
```
Optional: `apply_to_all=1`.

### dns_remove_blacklist
```bash
curl -s -X POST $API -d "dns_remove_blacklist=1&token=$TOKEN&tunnel_token=$TUNNEL&domain=evil.com"
```

### dns_blocklist_stats
```bash
curl -s -X POST $API -d "dns_blocklist_stats=1&token=$TOKEN"
```
Returns: `total_domains`, `lists[]` with per-list stats.

---

## Firewall

### firewall_rule_list
```bash
curl -s -X POST $API -d "firewall_rule_list=1&token=$TOKEN"
```
Optional: `tunnel_token` to filter. Returns: `link_all_enabled`, `rules[]`, `count`.

### firewall_rule_add
```bash
curl -s -X POST $API -d "firewall_rule_add=1&token=$TOKEN&tunnel_token=$TUNNEL&protocol=TCP&src_ip=0.0.0.0/0&src_port=ALL&dst_ip=TUNNEL_IP&dst_port=443"
```
Required: `tunnel_token`, `protocol` (TCP/UDP/ICMP/ALL), `src_ip`, `src_port`, `dst_ip`, `dst_port`.

### firewall_rule_delete
Same params as `firewall_rule_add`.
```bash
curl -s -X POST $API -d "firewall_rule_delete=1&token=$TOKEN&tunnel_token=$TUNNEL&protocol=TCP&src_ip=0.0.0.0/0&src_port=ALL&dst_ip=TUNNEL_IP&dst_port=443"
```

### firewall_link_all_toggle
Link all tunnels so they can reach each other (mesh network).
```bash
curl -s -X POST $API -d "firewall_link_all_toggle=1&token=$TOKEN&enabled=1"
```

### firewall_link_all_status
```bash
curl -s -X POST $API -d "firewall_link_all_status=1&token=$TOKEN"
```
Returns: `link_all_tunnels` (0 or 1).

---

## Domains

### list_domains
```bash
curl -s -X POST $API -d "list_domains=1&token=$TOKEN"
```
Returns: `domains[]` with `name`, `id`.

### create_domain
```bash
curl -s -X POST $API -d "create_domain=1&token=$TOKEN&domain=mysite.doxx"
```
196 TLDs available. If no TLD specified, defaults to `.doxx`.

**TLD categories:** Single letters (.b-.z), numbers (.8, .404, .1337), crypto (.btc, .crypto, .eth, .dao, .wallet), hacking (.cyber, .exploit, .onion, .tor, .pwnd), tech (.api, .dns, .lan, .vpn, .wireguard, .wg, .mesh, .local), gaming (.gamer, .gta6, .home, .vpn).

### delete_domain
```bash
curl -s -X POST $API -d "delete_domain=1&token=$TOKEN&domain=mysite.doxx"
```

### import_domain
Import external domains (.com, .net, etc.) via TXT record verification.
```bash
curl -s -X POST $API -d "import_domain=1&token=$TOKEN&domain=mysite.com"
```
Prerequisite: set TXT record `_doxx-verify.mysite.com` with code from `get_domain_validation`.
Returns: `nameservers` to configure at registrar (`a.root-dx.net`, `a.root-dx.com`, `a.root-dx.org`).

### get_domain_validation
Get TXT verification code for domain import.
```bash
curl -s -X POST $API -d "get_domain_validation=1&token=$TOKEN&domain=mysite.com"
```
Returns: `validation_code`.

---

## DNS Records

Supported types: `A`, `AAAA`, `CNAME`, `MX`, `TXT`, `NS`, `SRV`, `PTR`.

### list_dns
```bash
curl -s -X POST $API -d "list_dns=1&token=$TOKEN&domain=mysite.doxx"
```
Returns: `records[]` with `name`, `type`, `content`, `ttl`, `prio`.

### create_dns_record
```bash
curl -s -X POST $API -d "create_dns_record=1&token=$TOKEN&domain=mysite.doxx&name=mysite.doxx&type=A&content=1.2.3.4&ttl=300"
```
Required: `domain`, `name`, `type`, `content`. Optional: `ttl` (default 3600), `prio` (for MX).
SRV records use: `srv_priority`, `srv_weight`, `srv_port`, `srv_target`.

### update_dns_record
```bash
curl -s -X POST $API -d "update_dns_record=1&token=$TOKEN&domain=mysite.doxx&old_name=mysite.doxx&old_type=A&old_content=1.2.3.4&name=mysite.doxx&content=5.6.7.8&ttl=300"
```
Required: `old_name`, `old_type`, `old_content` (to identify record) + `name`, `content`, `ttl` (new values).

### delete_dns_record
```bash
curl -s -X POST $API -d "delete_dns_record=1&token=$TOKEN&domain=mysite.doxx&name=mysite.doxx&type=A&content=1.2.3.4"
```

---

## Public DNS (Secure DNS Sharing)

Create DoH/DoT endpoints that share your tunnel's DNS blocking config without VPN.

### public_dns_list_hashes
```bash
curl -s -X POST $API -d "public_dns_list_hashes=1&token=$TOKEN"
```
Returns: `hashes[]` with `host_hash`, `tunnel_token`, `doh_url`, `dot_host`.

### public_dns_create_hash
```bash
curl -s -X POST $API -d "public_dns_create_hash=1&token=$TOKEN&tunnel_token=$TUNNEL"
```
Returns: `host_hash`, `doh_url` (e.g. `https://HASH.sdns.doxx.net/dns-query`), `dot_host`.

### public_dns_delete_hash
```bash
curl -s -X POST $API -d "public_dns_delete_hash=1&token=$TOKEN&host_hash=HASH"
```

---

## Proxy

### get_proxy_config
```bash
curl -s -X POST $API -d "get_proxy_config=1&token=$TOKEN&tunnel_token=$TUNNEL"
```
Returns: `config` with `enabled`, `location`, `browser`.

### update_proxy_config
```bash
curl -s -X POST $API -d "update_proxy_config=1&token=$TOKEN&tunnel_token=$TUNNEL&enabled=1&location=newyork-us"
```
Optional: `enabled` (1/0), `location`, `browser`.

---

## Certificates

### sign_certificate
Sign a CSR with the doxx.net root CA. Auto-upgrades to wildcard (*.domain + domain).
**Returns raw PEM, not JSON.**
```bash
openssl ecparam -genkey -name prime256v1 -out domain.key 2>/dev/null
openssl req -new -key domain.key -out domain.csr -subj "/CN=mysite.doxx" 2>/dev/null
curl -s -X POST $API -d "sign_certificate=1&token=$TOKEN&domain=mysite.doxx" --data-urlencode "csr=$(cat domain.csr)" -o domain.crt
```
Required: `domain` (must own it), `csr` (PEM-encoded).

Root CA: `CN=doxx.net root CA` / RSA / valid Jan 2025 - Jan 2035. Signed certs valid 365 days.
Root CA download: `curl -o doxx-root-ca.crt https://a0x13.doxx.net/assets/doxx-root-ca.crt`

---

## Mobile

### get_mobile_options
```bash
curl -s -X POST $API -d "get_mobile_options=1&token=$TOKEN"
```
Returns: `connect_on_startup`, `kill_switch`, `transport`, `proxy_enabled`, `onion_enabled`.

### set_mobile_options
```bash
curl -s -X POST $API -d "set_mobile_options=1&token=$TOKEN&connect_on_startup=1&kill_switch=1"
```
Optional: `connect_on_startup`, `kill_switch`, `proxy_enabled`, `onion_enabled` (all 1/0).

---

## Utility

### version_check (no auth)
```bash
curl -s -X POST $API -d "version_check=1"
```
Returns: `version`, `download_url`.

### generate_qr (no auth)
**Returns binary PNG, not JSON.**
```bash
curl -s -X POST $API -d "generate_qr=1&data=TEXT_TO_ENCODE&size=512" -o qr.png
```
`size`: 100-2048 pixels, default 512.

---

## POW (Proof of Work)

### doxxpow_challenge (no auth)
Get a proof-of-work challenge.
```bash
curl -s -X POST $API -d "doxxpow_challenge=1"
```

### doxxpow_verify (no auth)
Submit completed POW solution.
```bash
curl -s -X POST $API -d "doxxpow_verify=1&challenge_id=ID&samples=SAMPLES"
```

### doxxpow_validate_token
Validate a POW token.
```bash
curl -s -X POST $API -d "doxxpow_validate_token=1&pow_token=TOKEN"
```
Returns: `valid`, `accuracy`.

---

## Stats API

Base URL: `https://secure-wss.doxx.net`

### GET /api/stats/bandwidth
```bash
curl -s "https://secure-wss.doxx.net/api/stats/bandwidth?token=$TOKEN&start=$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)&end=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```
Optional: `tunnel_token`, `start`, `end` (ISO 8601). Auto-granularity: 1s (<5m), 1m (<6h), 5m (<48h), 1h (<30d), 6h (30d+).

### GET /api/stats/alerts
```bash
curl -s "https://secure-wss.doxx.net/api/stats/alerts?token=$TOKEN&last=1d"
```
Optional: `tunnel_token`, `last` (session/1m/1h/1d/7d/30d), `start`/`end`, `type`.
Returns: `totals`, `block_count`, `category_counts`, `data[]`.

### GET /api/stats/summary
```bash
curl -s "https://secure-wss.doxx.net/api/stats/summary?token=$TOKEN&days=30"
```

### GET /api/stats/global (no auth)
```bash
curl -s "https://secure-wss.doxx.net/api/stats/global"
```
Returns: `total` (global threat counter), `ts`.

### WebSocket — Real-time events
```
wss://secure-wss.doxx.net/ws?token=TOKEN[&tunnel_token=TUNNEL]
```
Event types: `dns_block`, `security_event`, `dangerous_port`, `dns_bypass`, `doh_bypass`, `bandwidth`, `dns_nxdomain`, `tunnel_status`, `port_scan`.

Event fields: `tunnel_token`, `ts`, `type`, `action`, `category`, `value`, `count`, `display`.

### WebSocket — Global threat counter (no auth)
```
wss://secure-wss.doxx.net/ws/global
```

---

## Conntrack API

Real-time connection tracking across VPN backbone nodes.

### WebSocket
```
wss://conntrack.doxx.net/ws?token=TOKEN
```
First message: `type: "initial"` (all current connections). Then `type: "snapshot"` every 10s.

Connection fields: `id`, `protocol`, `state`, `src_ip`, `dst_ip`, `src_port`, `dst_port`, `bytes_sent`, `bytes_recv`, `upload_speed`, `download_speed`, `server`, `tunnel_name`.

Stats fields: `total_connections`, `total_upload`, `total_download`, `upload_speed`, `download_speed`, `protocol_breakdown`.

### Health check (no auth)
```bash
curl -s https://conntrack.doxx.net/health
```

---

## DNS Infrastructure

| Layer | Address | Purpose |
|-------|---------|---------|
| VPN Recursive | `10.10.10.10`, `fd53::` | VPN clients — personalized blocking, DNSSEC, resolves all .doxx TLDs |
| Public Recursive | `207.207.200.200`, `207.207.201.201` | Anyone — resolves .doxx TLDs + internet domains |
| Public Recursive IPv6 | `2602:f5c1::` (Americas), `2a11:46c0::` (Europe) | Same as above, IPv6 |
| DoH | `https://doxx.net/dns-query` | DNS-over-HTTPS (public) |
| DoT | `doxx.net:853` | DNS-over-TLS (public) |
| Authoritative | `a.root-dx.net` / `.com` / `.org` | Nameservers for hosted domains |

Verify DNS: `dig A mysite.doxx @a.root-dx.net +short`
Resolve from anywhere: `dig A mysite.doxx @207.207.200.200 +short`

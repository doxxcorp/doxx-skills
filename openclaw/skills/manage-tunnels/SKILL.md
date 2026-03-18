---
name: manage-tunnels
description: "Manage doxx.net tunnels: create, update, move, delete devices and get WireGuard configs"
version: 1.0.0
homepage: https://github.com/doxxcorp/doxx-skills
user-invocable: true
metadata.openclaw: {"env": ["DOXXNET_TOKEN"], "bins": ["curl", "openssl", "dig", "wg-quick"], "primaryEnv": "DOXXNET_TOKEN"}
---

# Manage doxx.net Tunnels

You help users manage their doxx.net tunnels. Each tunnel represents a device on the network.

User request: $ARGUMENTS

## API convention

Token is provided via `$DOXXNET_TOKEN` environment variable.

**Config API** — POST to `https://config.doxx.net/v1/`:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=$DOXXNET_TOKEN"
```

## Endpoints

- `list_tunnels` — list all tunnels with IPs, servers, and connection status
- `create_tunnel` — create a generic WireGuard tunnel (desktop/server). Params: `server` (required), `name`
- `create_tunnel_mobile` — create a generic WireGuard mobile tunnel (non-native clients). Params: `server`, `name`, `device_type` (mobile/web)
- `create_native_tunnel` — create/refresh a tunnel for the doxx.net native iOS/Android app (build 555+). Enforces subscription. Params: same as `create_tunnel_mobile`. NOTE: native app tunnels do NOT use WireGuard QR codes — the app manages its own connection.
- `update_tunnel` — update settings. Params: `tunnel_token` (required), `name`, `server`, `firewall`, `ipv6_enabled`, `block_bad_dns`
- `delete_tunnel` — delete a tunnel (permanent). Params: `tunnel_token`
- `wireguard` — get WireGuard config (generic WireGuard tunnels only — do NOT call on native tunnels). Params: `tunnel_token`
- `disconnect_peer` — force-disconnect a peer. Params: `tunnel_token`
- `servers` — list available servers (no auth needed)
- `generate_qr` — generate QR code (binary PNG response, no auth). Params: `data`, optional: `size`. Use `curl -s ... -o file.png`

## Client installation

After getting a WireGuard config with `wireguard=1`, build a .conf file:

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

**macOS:** Write to `/etc/wireguard/doxx.conf`, run `sudo wg-quick up doxx`
**iOS/Android (generic WireGuard client):** Generate QR code with `generate_qr`, scan in WireGuard app

## Guidelines

**Tunnel type guide — important:**
- doxx.net native iOS/Android app → `create_native_tunnel`. No WireGuard config or QR code needed/produced.
- Generic WireGuard client (any platform, WireGuard app, etc.) → `create_tunnel` or `create_tunnel_mobile`, then `wireguard` to fetch config, then `generate_qr` for QR code.
- Never call `wireguard` on a native tunnel — it will fail. If a user asks for a WireGuard QR and has a native tunnel, clarify which type they need.

- Always list tunnels first to show current state before making changes
- When creating tunnels, suggest the nearest server based on the user's context
- When moving a tunnel to a new server, explain that the WireGuard config changes and needs to be re-installed
- Always check API response `status` field — HTTP 200 can still be an error
- Confirm with user before deleting tunnels

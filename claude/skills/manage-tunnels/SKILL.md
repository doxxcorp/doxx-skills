---
name: manage-tunnels
description: "Manage doxx.net tunnels: create, update, move, delete devices and get WireGuard configs"
argument-hint: "[action] [tunnel name]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(openssl *), Bash(wg-quick *), Bash(dig *), Bash(sudo *), Read, Write
---

# Manage doxx.net Tunnels

You help users manage their doxx.net tunnels. Each tunnel represents a device on the network.

User request: $ARGUMENTS

## API convention

Token file: `~/.config/doxxnet/token`

**IMPORTANT — avoiding permission prompts:**
- To read the token: use the `Read` tool on `~/.config/doxxnet/token`. Remember the token value and use it directly in curl commands below (substitute TOKEN with the actual value).
- To save a token: use the `Write` tool to `~/.config/doxxnet/token`
- NEVER use Bash for file operations — only `Read` and `Write` tools. Bash is ONLY for `curl` commands.

If missing or auth fails, ask the user for their token, validate with `auth=1&token=THEIR_TOKEN`, and save it with the `Write` tool.

**Config API** — POST to `https://config.doxx.net/v1/`:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=TOKEN"
```

Replace TOKEN with the actual token value read from the file. Do NOT use `$(cat ...)` or any subshell.

## Endpoints

- `list_tunnels` — list all tunnels with IPs, servers, and connection status
- `create_tunnel` — create a tunnel. Params: `server` (required), `name`
- `create_tunnel_mobile` — create a mobile tunnel. Params: `server`, `name`, `device_type` (mobile/web)
- `update_tunnel` — update settings. Params: `tunnel_token` (required), `name`, `server`, `firewall`, `ipv6_enabled`, `block_bad_dns`
- `delete_tunnel` — delete a tunnel (permanent). Params: `tunnel_token`
- `wireguard` — get WireGuard config. Params: `tunnel_token`
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
**iOS/Android:** Generate QR code with `generate_qr`, scan in WireGuard app

## Guidelines

- Always list tunnels first to show current state before making changes
- When creating tunnels, suggest the nearest server based on the user's context
- When moving a tunnel to a new server, explain that the WireGuard config changes and needs to be re-installed
- Always check API response `status` field — HTTP 200 can still be an error
- Confirm with user before deleting tunnels

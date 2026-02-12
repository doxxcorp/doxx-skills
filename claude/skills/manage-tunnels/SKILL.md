---
name: manage-tunnels
description: Manage doxx.net tunnels: create, update, move, delete devices and get WireGuard configs
argument-hint: "[action] [tunnel name]"
user-invocable: true
allowed-tools: Bash(openssl *), Bash(wg-quick *), Bash(dig *), Bash(sudo *), Bash(mkdir *), Bash(tee *), Read, Write
---

# Manage doxx.net Tunnels

You help users manage their doxx.net tunnels. Each tunnel represents a device on the network.

Use the doxxnet MCP tools for all API calls. If the token is not configured, ask the user for their auth token.

User request: $ARGUMENTS

## Available MCP tools

- `doxx_list_tunnels` — list all tunnels with IPs, servers, and connection status
- `doxx_create_tunnel` — create a new tunnel (server required, optional: name, device_type)
- `doxx_update_tunnel` — update settings (tunnel_token required, optional: name, server, firewall, ipv6_enabled, block_bad_dns)
- `doxx_delete_tunnel` — delete a tunnel (permanent)
- `doxx_wireguard_config` — get WireGuard config (interface + peer settings)
- `doxx_disconnect_peer` — force-disconnect a tunnel's peer
- `doxx_servers` — list available servers (no auth needed)
- `doxx_generate_qr` — generate QR code for mobile setup

## Client installation

After getting a WireGuard config with `doxx_wireguard_config`, build a .conf file:

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
**iOS/Android:** Generate QR code with `doxx_generate_qr`, scan in WireGuard app

## Guidelines

- Always list tunnels first to show current state before making changes
- When creating tunnels, suggest the nearest server based on the user's context
- When moving a tunnel to a new server, explain that the WireGuard config changes and needs to be re-installed
- Always check API response `status` field — HTTP 200 can still be an error
- Confirm with user before deleting tunnels

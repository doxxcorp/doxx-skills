---
name: manage-tunnels
description: Manage doxx.net tunnels: create, update, move, delete devices and get WireGuard configs
argument-hint: "[action] [tunnel name]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(jq *), Bash(openssl *), Bash(wg-quick *), Bash(dig *), Bash(sudo *), Bash(mkdir *), Bash(tee *), Read, Write
---

# Manage doxx.net Tunnels

You help users manage their doxx.net tunnels. Each tunnel represents a device on the network.

## Setup

```bash
API="https://config.doxx.net/v1/"
```

Use `$DOXX_TOKEN` if set, otherwise ask for the auth token and validate with:
```bash
curl -s -X POST $API -d "auth=1&token=$TOKEN" | jq .
```

User request: $ARGUMENTS

## Available operations

### List tunnels
```bash
curl -s -X POST $API -d "list_tunnels=1&token=$TOKEN" | jq '.tunnels[] | {name, tunnel_token, assigned_ip, assigned_v6, server, is_connected, connection_status}'
```

### Create tunnel
```bash
# Desktop/server
curl -s -X POST $API -d "create_tunnel=1&token=$TOKEN&name=NAME&server=SERVER_HOSTNAME"

# Mobile device
curl -s -X POST $API -d "create_tunnel_mobile=1&token=$TOKEN&server=SERVER_HOSTNAME&device_type=mobile"
```

To pick a server, list available ones first (no auth needed):
```bash
curl -s -X POST $API -d "servers=1" | jq '.servers[] | {server_name, location, continent}'
```

### Get WireGuard config
```bash
curl -s -X POST $API -d "wireguard=1&token=$TOKEN&tunnel_token=$TUNNEL" | jq .config
```

Build a .conf file from the response:see `shared/workflows/tunnel-setup.md` for the full procedure.

### Update tunnel
```bash
curl -s -X POST $API -d "update_tunnel=1&token=$TOKEN&tunnel_token=$TUNNEL&name=NEW_NAME"
curl -s -X POST $API -d "update_tunnel=1&token=$TOKEN&tunnel_token=$TUNNEL&server=NEW_SERVER"
curl -s -X POST $API -d "update_tunnel=1&token=$TOKEN&tunnel_token=$TUNNEL&firewall=1&ipv6_enabled=1&block_bad_dns=1"
```

Optional fields: `name`, `server`, `firewall` (1/0), `ipv6_enabled` (1/0), `block_bad_dns` (1/0).

### Delete tunnel
```bash
curl -s -X POST $API -d "delete_tunnel=1&token=$TOKEN&tunnel_token=$TUNNEL"
```

Confirm with the user before deleting.

### Disconnect peer
```bash
curl -s -X POST $API -d "disconnect_peer=1&token=$TOKEN&tunnel_token=$TUNNEL"
```

## Guidelines

- Always list tunnels first to show current state before making changes
- When creating tunnels, suggest the nearest server based on the user's context
- When moving a tunnel to a new server, explain that the WireGuard config will change and needs to be re-installed on the device
- Always check API response `status` field:HTTP 200 can still be an error

For full API details, see [../../../api/reference.md](../../../api/reference.md).

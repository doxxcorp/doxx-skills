---
name: manage-tunnels
description: Manage doxx.net tunnels: create, update, move, delete devices and get WireGuard configs
argument-hint: "[action] [tunnel name]"
user-invocable: true
allowed-tools: Bash(python3 *), Bash(openssl *), Bash(wg-quick *), Bash(dig *), Bash(sudo *), Bash(mkdir *), Bash(tee *), Read, Write
---

# Manage doxx.net Tunnels

You help users manage their doxx.net tunnels. Each tunnel represents a device on the network.

## Setup

All API calls use the helper script. Locate it first:
```bash
DOXXNET_API=$(find ~/.claude/plugins -name "doxx-api.py" -path "*/doxxnet/*" 2>/dev/null | head -1)
```

If `$DOXXNET_TOKEN` is not set in the environment, ask for the auth token and validate with:
```bash
python3 $DOXXNET_API auth token=TOKEN_VALUE
```

User request: $ARGUMENTS

## Available operations

### List tunnels
```bash
python3 $DOXXNET_API list_tunnels
```

### Create tunnel
```bash
# Desktop/server
python3 $DOXXNET_API create_tunnel name=NAME server=SERVER_HOSTNAME

# Mobile device
python3 $DOXXNET_API create_tunnel_mobile server=SERVER_HOSTNAME device_type=mobile
```

To pick a server, list available ones first (no auth needed):
```bash
python3 $DOXXNET_API servers
```

### Get WireGuard config
```bash
python3 $DOXXNET_API wireguard tunnel_token=TUNNEL
```

Build a .conf file from the response:see `shared/workflows/tunnel-setup.md` for the full procedure.

### Update tunnel
```bash
python3 $DOXXNET_API update_tunnel tunnel_token=TUNNEL name=NEW_NAME
python3 $DOXXNET_API update_tunnel tunnel_token=TUNNEL server=NEW_SERVER
python3 $DOXXNET_API update_tunnel tunnel_token=TUNNEL firewall=1 ipv6_enabled=1 block_bad_dns=1
```

Optional fields: `name`, `server`, `firewall` (1/0), `ipv6_enabled` (1/0), `block_bad_dns` (1/0).

### Delete tunnel
```bash
python3 $DOXXNET_API delete_tunnel tunnel_token=TUNNEL
```

Confirm with the user before deleting.

### Disconnect peer
```bash
python3 $DOXXNET_API disconnect_peer tunnel_token=TUNNEL
```

## Guidelines

- Always list tunnels first to show current state before making changes
- When creating tunnels, suggest the nearest server based on the user's context
- When moving a tunnel to a new server, explain that the WireGuard config will change and needs to be re-installed on the device
- Always check API response `status` field:HTTP 200 can still be an error

For full API details, see [../../../api/reference.md](../../../api/reference.md).

# Workflow: Tunnel Setup

Agent-neutral procedure for creating and configuring a single encrypted tunnel.

## Variables

- `API` = `https://config.doxx.net/v1/`
- `TOKEN` = user's auth token
- `SERVER` = server hostname (e.g., `wireguard.mia.us.doxx.net`)

---

## Step 1: Select a server

```bash
curl -s -X POST $API -d "servers=1" | jq '.servers[] | {server_name, location, continent}'
```

## Step 2: Create the tunnel

**Desktop/Server:**
```bash
curl -s -X POST $API -d "create_tunnel=1&token=$TOKEN&name=DEVICE_NAME&server=$SERVER"
```

**Mobile:**
```bash
curl -s -X POST $API -d "create_tunnel_mobile=1&token=$TOKEN&server=$SERVER&device_type=mobile"
```

## Step 3: Get tunnel token

```bash
curl -s -X POST $API -d "list_tunnels=1&token=$TOKEN" | jq '.tunnels[-1] | {tunnel_token, name, assigned_ip, server}'
```

## Step 4: Get WireGuard config

```bash
TUNNEL="tunnel_token_from_step_3"
curl -s -X POST $API -d "wireguard=1&token=$TOKEN&tunnel_token=$TUNNEL" | jq .config
```

## Step 5: Build .conf file

```bash
CONFIG=$(curl -s -X POST $API -d "wireguard=1&token=$TOKEN&tunnel_token=$TUNNEL")

cat << EOF
[Interface]
PrivateKey = $(echo $CONFIG | jq -r '.config.interface.private_key')
Address = $(echo $CONFIG | jq -r '.config.interface.address')
DNS = $(echo $CONFIG | jq -r '.config.interface.dns')

[Peer]
PublicKey = $(echo $CONFIG | jq -r '.config.peer.public_key')
AllowedIPs = $(echo $CONFIG | jq -r '.config.peer.allowed_ips')
Endpoint = $(echo $CONFIG | jq -r '.config.peer.endpoint')
PersistentKeepalive = 25
EOF
```

## Step 6: Connect

See platform-specific guides in `client-guides/`.

## Managing the tunnel later

**Rename:**
```bash
curl -s -X POST $API -d "update_tunnel=1&token=$TOKEN&tunnel_token=$TUNNEL&name=NEW_NAME"
```

**Move to different server:**
```bash
curl -s -X POST $API -d "update_tunnel=1&token=$TOKEN&tunnel_token=$TUNNEL&server=NEW_SERVER"
```

**Toggle features:**
```bash
curl -s -X POST $API -d "update_tunnel=1&token=$TOKEN&tunnel_token=$TUNNEL&firewall=1&ipv6_enabled=1&block_bad_dns=1"
```

**Delete:**
```bash
curl -s -X POST $API -d "delete_tunnel=1&token=$TOKEN&tunnel_token=$TUNNEL"
```

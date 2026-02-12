# Android:WireGuard Setup

## Prerequisites

- WireGuard app installed from Google Play Store
- Auth token and tunnel already created via the doxx.net API (use `create_tunnel_mobile` with `device_type=mobile`)

## Setup via QR Code (recommended)

### 1. Generate QR code from API

```bash
API="https://config.doxx.net/v1/"

# Get WireGuard config
CONFIG=$(curl -s -X POST $API -d "wireguard=1&token=$TOKEN&tunnel_token=$TUNNEL")

# Build the config string
PRIVATE_KEY=$(echo $CONFIG | jq -r '.config.interface.private_key')
ADDRESS=$(echo $CONFIG | jq -r '.config.interface.address')
DNS=$(echo $CONFIG | jq -r '.config.interface.dns')
PEER_KEY=$(echo $CONFIG | jq -r '.config.peer.public_key')
ENDPOINT=$(echo $CONFIG | jq -r '.config.peer.endpoint')
ALLOWED_IPS=$(echo $CONFIG | jq -r '.config.peer.allowed_ips')

WG_CONF="[Interface]
PrivateKey = $PRIVATE_KEY
Address = $ADDRESS
DNS = $DNS

[Peer]
PublicKey = $PEER_KEY
AllowedIPs = $ALLOWED_IPS
Endpoint = $ENDPOINT
PersistentKeepalive = 25"

# Generate QR code
curl -s -X POST $API --data-urlencode "generate_qr=1" --data-urlencode "data=$WG_CONF" --data-urlencode "size=512" -o doxx-qr.png
```

### 2. Scan in WireGuard app

1. Open WireGuard app on Android
2. Tap **+** → **Scan from QR code**
3. Scan the QR code from your screen
4. Name the tunnel (e.g., "doxx.net")
5. Allow VPN configuration when prompted
6. Toggle the tunnel **ON**

## Setup via Secure DNS (no app needed)

For DNS blocking only (no tunnel), use Private DNS:

### 1. Create a Secure DNS hash

```bash
curl -s -X POST $API -d "public_dns_create_hash=1&token=$TOKEN&tunnel_token=$TUNNEL" | jq .
```

### 2. Configure on Android

1. Go to **Settings → Network & Internet → Private DNS**
2. Select **Private DNS provider hostname**
3. Enter the DoT hostname: `HASH.sdns.doxx.net`

## Verify

- Open Chrome and visit any website:should load normally
- Try resolving a .doxx domain (if you have one registered)
- Check doxx.net portal for connection status

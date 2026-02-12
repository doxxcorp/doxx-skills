# Workflow: Client Installation

Agent-neutral procedure for installing WireGuard on user devices and connecting to doxx.net.

## Prerequisites

- Auth token (`$TOKEN`)
- Tunnel already created, tunnel token available (`$TUNNEL`)

## Variables

- `API` = `https://config.doxx.net/v1/`

---

## Step 1: Get WireGuard config from API

```bash
CONFIG=$(curl -s -X POST $API -d "wireguard=1&token=$TOKEN&tunnel_token=$TUNNEL")
echo $CONFIG | jq .config
```

## Step 2: Build the .conf content

```bash
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
```

---

## Step 3: Install per platform

### macOS

```bash
brew install wireguard-tools
sudo mkdir -p /etc/wireguard
echo "$WG_CONF" | sudo tee /etc/wireguard/doxx.conf > /dev/null
sudo wg-quick up doxx
```

Verify: `sudo wg show` and `dig A doxx.net @10.10.10.10 +short`

See: `client-guides/macos.md`

### iOS

Generate QR code:
```bash
curl -s -X POST $API --data-urlencode "generate_qr=1" --data-urlencode "data=$WG_CONF" --data-urlencode "size=512" -o doxx-qr.png
```

Then: open WireGuard app → + → Scan QR code → toggle ON.

See: `client-guides/ios.md`

### Android

Generate QR code (same as iOS above).

Then: open WireGuard app → + → Scan QR code → toggle ON.

See: `client-guides/android.md`

### Linux

```bash
sudo apt install wireguard  # Debian/Ubuntu
sudo mkdir -p /etc/wireguard
echo "$WG_CONF" | sudo tee /etc/wireguard/doxx.conf > /dev/null
sudo wg-quick up doxx
```

Auto-start: `sudo systemctl enable wg-quick@doxx`

---

## Step 4: Verify connection

```bash
# Check WireGuard handshake
sudo wg show

# Verify tunnel DNS works
dig A doxx.net @10.10.10.10 +short

# Check your public IP changed (should be the server's IP)
curl -s https://ifconfig.me
```

## Disconnect

```bash
sudo wg-quick down doxx
```

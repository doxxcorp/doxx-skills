# macOS:WireGuard Setup

## Prerequisites

- WireGuard installed: `brew install wireguard-tools`
- Auth token and tunnel already created via the doxx.net API

## Setup

### 1. Get WireGuard config from API

```bash
API="https://config.doxx.net/v1/"
CONFIG=$(curl -s -X POST $API -d "wireguard=1&token=$TOKEN&tunnel_token=$TUNNEL")
```

### 2. Build the .conf file

```bash
PRIVATE_KEY=$(echo $CONFIG | jq -r '.config.interface.private_key')
ADDRESS=$(echo $CONFIG | jq -r '.config.interface.address')
DNS=$(echo $CONFIG | jq -r '.config.interface.dns')
PEER_KEY=$(echo $CONFIG | jq -r '.config.peer.public_key')
ENDPOINT=$(echo $CONFIG | jq -r '.config.peer.endpoint')
ALLOWED_IPS=$(echo $CONFIG | jq -r '.config.peer.allowed_ips')

sudo mkdir -p /etc/wireguard
sudo tee /etc/wireguard/doxx.conf > /dev/null << EOF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = $ADDRESS
DNS = $DNS

[Peer]
PublicKey = $PEER_KEY
AllowedIPs = $ALLOWED_IPS
Endpoint = $ENDPOINT
PersistentKeepalive = 25
EOF
```

### 3. Connect

```bash
sudo wg-quick up doxx
```

### 4. Verify

```bash
# Check WireGuard status
sudo wg show

# Verify DNS resolution of .doxx domains
dig A doxx.net @10.10.10.10 +short
```

## Disconnect

```bash
sudo wg-quick down doxx
```

## Auto-start on boot

```bash
# Create a LaunchDaemon
sudo tee /Library/LaunchDaemons/com.doxx.wireguard.plist > /dev/null << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.doxx.wireguard</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/wg-quick</string>
        <string>up</string>
        <string>doxx</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

sudo launchctl load /Library/LaunchDaemons/com.doxx.wireguard.plist
```

## Alternative: WireGuard macOS App

1. Install from App Store: search "WireGuard"
2. Open the app, click "Import Tunnel(s) from File"
3. Select your `doxx.conf` file
4. Click "Activate"

## Install doxx.net Root CA (for TLS with .doxx domains)

```bash
curl -o /tmp/doxx-root-ca.crt https://a0x13.doxx.net/assets/doxx-root-ca.crt
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/doxx-root-ca.crt
```

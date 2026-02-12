# macOS:WireGuard Setup

## Prerequisites

- WireGuard installed: `brew install wireguard-tools`
- Python 3 (included with macOS)
- Auth token and tunnel already created via the doxx.net API

## Setup

### 1. Get WireGuard config and build .conf file

```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ.get('DOXXNET_TOKEN') or input('Enter your auth token: ')
TUNNEL = os.environ.get('TUNNEL_TOKEN') or input('Enter your tunnel token: ')

data = urllib.parse.urlencode({'wireguard': '1', 'token': TOKEN, 'tunnel_token': TUNNEL}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
cfg = json.loads(resp.read())['config']

iface = cfg['interface']
peer = cfg['peer']

conf = f'''[Interface]
PrivateKey = {iface[\"private_key\"]}
Address = {iface[\"address\"]}
DNS = {iface[\"dns\"]}

[Peer]
PublicKey = {peer[\"public_key\"]}
AllowedIPs = {peer[\"allowed_ips\"]}
Endpoint = {peer[\"endpoint\"]}
PersistentKeepalive = 25'''

print(conf)
open('/tmp/doxx.conf', 'w').write(conf)
print('\nConfig written to /tmp/doxx.conf')
"
```

### 2. Install config and connect

```bash
sudo mkdir -p /etc/wireguard
sudo cp /tmp/doxx.conf /etc/wireguard/doxx.conf
sudo wg-quick up doxx
```

### 3. Verify

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
python3 -c "import urllib.request; urllib.request.urlretrieve('https://a0x13.doxx.net/assets/doxx-root-ca.crt', '/tmp/doxx-root-ca.crt')"
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/doxx-root-ca.crt
```

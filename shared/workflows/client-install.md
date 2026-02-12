# Workflow: Client Installation

Agent-neutral procedure for installing WireGuard on user devices and connecting to doxx.net.

## Prerequisites

- Python 3
- Auth token (`$DOXXNET_TOKEN`)
- Tunnel already created, tunnel token available (`$TUNNEL`)

## Variables

- `API` = `https://config.doxx.net/v1/`

---

## Step 1: Get WireGuard config from API

```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
TUNNEL = os.environ.get('TUNNEL_TOKEN') or input('Enter tunnel token: ')

data = urllib.parse.urlencode({'wireguard': '1', 'token': TOKEN, 'tunnel_token': TUNNEL}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
cfg = json.loads(resp.read())['config']
print(json.dumps(cfg, indent=2))
"
```

## Step 2: Build the .conf content

```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
TUNNEL = os.environ.get('TUNNEL_TOKEN') or input('Enter tunnel token: ')

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

---

## Step 3: Install per platform

### macOS

```bash
brew install wireguard-tools
sudo mkdir -p /etc/wireguard
sudo cp /tmp/doxx.conf /etc/wireguard/doxx.conf
sudo wg-quick up doxx
```

Verify: `sudo wg show` and `dig A doxx.net @10.10.10.10 +short`

See: `client-guides/macos.md`

### iOS

Generate QR code:
```bash
python3 -c "
import urllib.request, urllib.parse

API = 'https://config.doxx.net/v1/'
wg_conf = open('/tmp/doxx.conf').read()
data = urllib.parse.urlencode({'generate_qr': '1', 'data': wg_conf, 'size': '512'}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
open('doxx-qr.png', 'wb').write(resp.read())
print('QR code saved to doxx-qr.png')
"
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
sudo cp /tmp/doxx.conf /etc/wireguard/doxx.conf
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
python3 -c "import urllib.request; print(urllib.request.urlopen('https://ifconfig.me').read().decode())"
```

## Disconnect

```bash
sudo wg-quick down doxx
```

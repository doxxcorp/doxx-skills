# iOS:WireGuard Setup

## Prerequisites

- WireGuard app installed from App Store
- Python 3 (on the machine generating the QR code)
- Auth token and tunnel already created via the doxx.net API (use `create_tunnel_mobile` with `device_type=mobile`)

## Setup via QR Code (recommended)

### 1. Generate QR code from API

```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ.get('DOXXNET_TOKEN') or input('Enter your auth token: ')
TUNNEL = os.environ.get('TUNNEL_TOKEN') or input('Enter your tunnel token: ')

# Get WireGuard config
data = urllib.parse.urlencode({'wireguard': '1', 'token': TOKEN, 'tunnel_token': TUNNEL}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
cfg = json.loads(resp.read())['config']

iface = cfg['interface']
peer = cfg['peer']

wg_conf = f'''[Interface]
PrivateKey = {iface[\"private_key\"]}
Address = {iface[\"address\"]}
DNS = {iface[\"dns\"]}

[Peer]
PublicKey = {peer[\"public_key\"]}
AllowedIPs = {peer[\"allowed_ips\"]}
Endpoint = {peer[\"endpoint\"]}
PersistentKeepalive = 25'''

# Generate QR code
qr_data = urllib.parse.urlencode({'generate_qr': '1', 'data': wg_conf, 'size': '512'}).encode()
qr_resp = urllib.request.urlopen(urllib.request.Request(API, data=qr_data, method='POST'))
open('doxx-qr.png', 'wb').write(qr_resp.read())
print('QR code saved to doxx-qr.png')
"
```

### 2. Scan in WireGuard app

1. Open WireGuard app on iOS
2. Tap **+** → **Create from QR code**
3. Scan the QR code from your screen
4. Name the tunnel (e.g., "doxx.net")
5. Allow VPN configuration when prompted
6. Toggle the tunnel **ON**

## Setup via Secure DNS (no app needed)

For DNS blocking only (no tunnel), use Secure DNS:

### 1. Create a Secure DNS hash

```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ.get('DOXXNET_TOKEN') or input('Enter your auth token: ')
TUNNEL = os.environ.get('TUNNEL_TOKEN') or input('Enter your tunnel token: ')

data = urllib.parse.urlencode({'public_dns_create_hash': '1', 'token': TOKEN, 'tunnel_token': TUNNEL}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
print(json.dumps(json.loads(resp.read()), indent=2))
"
```

### 2. Configure on iOS

1. Go to **Settings → General → VPN & Device Management → DNS**
2. Select **Add Server** → **DNS over HTTPS**
3. Enter the DoH URL: `https://HASH.sdns.doxx.net/dns-query`

## Verify

- Open Safari and visit any website:should load normally
- Try resolving a .doxx domain (if you have one registered)
- Check doxx.net portal for connection status

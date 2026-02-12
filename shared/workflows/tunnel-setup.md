# Workflow: Tunnel Setup

Agent-neutral procedure for creating and configuring a single encrypted tunnel.

## Variables

- `API` = `https://config.doxx.net/v1/`
- `TOKEN` = user's auth token
- `SERVER` = server hostname (e.g., `wireguard.mia.us.doxx.net`)

---

## Step 1: Select a server

```bash
python3 -c "
import urllib.request, urllib.parse, json

API = 'https://config.doxx.net/v1/'
data = urllib.parse.urlencode({'servers': '1'}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
servers = json.loads(resp.read())['servers']
for s in servers:
    print(f\"{s['server_name']:40} {s['location']:20} {s['continent']}\")
"
```

## Step 2: Create the tunnel

**Desktop/Server:**
```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
SERVER = input('Server hostname: ')
NAME = input('Device name: ')

data = urllib.parse.urlencode({'create_tunnel': '1', 'token': TOKEN, 'name': NAME, 'server': SERVER}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
print(json.dumps(json.loads(resp.read()), indent=2))
"
```

**Mobile:**
```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
SERVER = input('Server hostname: ')

data = urllib.parse.urlencode({'create_tunnel_mobile': '1', 'token': TOKEN, 'server': SERVER, 'device_type': 'mobile'}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
print(json.dumps(json.loads(resp.read()), indent=2))
"
```

## Step 3: Get tunnel token

```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']

data = urllib.parse.urlencode({'list_tunnels': '1', 'token': TOKEN}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
tunnels = json.loads(resp.read())['tunnels']
latest = tunnels[-1]
print(f\"tunnel_token: {latest['tunnel_token']}\")
print(f\"name:         {latest['name']}\")
print(f\"assigned_ip:  {latest['assigned_ip']}\")
print(f\"server:       {latest['server']}\")
"
```

## Step 4: Get WireGuard config

```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
TUNNEL = input('Tunnel token: ')

data = urllib.parse.urlencode({'wireguard': '1', 'token': TOKEN, 'tunnel_token': TUNNEL}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
print(json.dumps(json.loads(resp.read())['config'], indent=2))
"
```

## Step 5: Build .conf file

```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
TUNNEL = input('Tunnel token: ')

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
"
```

## Step 6: Connect

See platform-specific guides in `client-guides/`.

## Managing the tunnel later

**Rename:**
```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
TUNNEL = input('Tunnel token: ')
NAME = input('New name: ')

data = urllib.parse.urlencode({'update_tunnel': '1', 'token': TOKEN, 'tunnel_token': TUNNEL, 'name': NAME}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
print(json.dumps(json.loads(resp.read()), indent=2))
"
```

**Move to different server:**
```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
TUNNEL = input('Tunnel token: ')
SERVER = input('New server: ')

data = urllib.parse.urlencode({'update_tunnel': '1', 'token': TOKEN, 'tunnel_token': TUNNEL, 'server': SERVER}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
print(json.dumps(json.loads(resp.read()), indent=2))
"
```

**Toggle features:**
```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
TUNNEL = input('Tunnel token: ')

data = urllib.parse.urlencode({'update_tunnel': '1', 'token': TOKEN, 'tunnel_token': TUNNEL, 'firewall': '1', 'ipv6_enabled': '1', 'block_bad_dns': '1'}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
print(json.dumps(json.loads(resp.read()), indent=2))
"
```

**Delete:**
```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
TUNNEL = input('Tunnel token: ')

data = urllib.parse.urlencode({'delete_tunnel': '1', 'token': TOKEN, 'tunnel_token': TUNNEL}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
print(json.dumps(json.loads(resp.read()), indent=2))
"
```

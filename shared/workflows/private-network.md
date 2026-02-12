# Workflow: Set Up a Private Network

Agent-neutral procedure for building a complete doxx.net private network from scratch. Agents should adapt the prompts and interactions to their native format.

## Prerequisites

Python 3 is required for JSON processing and API calls.

## Variables

- `API` = `https://config.doxx.net/v1/`
- `TOKEN` = user's auth token (obtained in Phase 1)
- `TUNNEL` = tunnel token (obtained in Phase 4)

All API calls are `POST` with form-encoded parameters. Example using Python:
```python
import urllib.request, urllib.parse, json
data = urllib.parse.urlencode({'endpoint_name': '1', 'token': TOKEN}).encode()
req = urllib.request.Request(API, data=data, method='POST')
resp = json.loads(urllib.request.urlopen(req).read())
```

---

## Phase 1: Authentication

**Goal:** Obtain and validate the user's auth token.

1. Ask user if they have a doxx.net auth token
2. **If yes:** ask them to provide it, then validate:
   ```python
   data = urllib.parse.urlencode({'auth': '1', 'token': TOKEN}).encode()
   req = urllib.request.Request(API, data=data, method='POST')
   resp = json.loads(urllib.request.urlopen(req).read())
   # resp['status'] should be 'success'
   ```
   - If `"success"` → proceed
   - If `"error"` → token is invalid, ask them to check and retry
3. **If no:** explain they must create an account at `https://a0x13.doxx.net`
   - Account creation is human-only (proof-of-work gated)
   - Cannot be done via API:this is by design
   - Offer to wait while they create one

**Important:** The auth token IS the user's identity. There are no usernames or passwords.

---

## Phase 2: Token Storage

**Goal:** Optionally persist the token for future sessions.

1. Ask user if they want to store the token
2. Options:
   - **Environment variable:** add `export DOXXNET_TOKEN=...` to shell profile
   - **.env file:** write to `.env` in current directory
   - **No storage:** user provides token each time
3. Warn: "This token is your identity. Keep it safe. There are no passwords."
4. Offer to generate recovery codes:
   ```python
   data = urllib.parse.urlencode({'create_account_recovery': '1', 'token': TOKEN}).encode()
   req = urllib.request.Request(API, data=data, method='POST')
   resp = json.loads(urllib.request.urlopen(req).read())
   ```
   - Tell user to save the codes somewhere safe
   - These are the only way to recover a lost token

---

## Phase 3: Server Selection

**Goal:** Choose a server location.

1. Fetch server list (no auth needed):
   ```python
   data = urllib.parse.urlencode({'servers': '1'}).encode()
   req = urllib.request.Request(API, data=data, method='POST')
   resp = json.loads(urllib.request.urlopen(req).read())
   # resp['servers'] contains server list with server_name, location, continent
   ```
2. Present servers grouped by continent
3. Ask user which server is closest to them, or suggest based on context
4. Store selected `SERVER_NAME` for tunnel creation

---

## Phase 4: Tunnel Creation

**Goal:** Create tunnels for each device.

1. Ask: "How many devices will be on this network?"
2. For each device:
   - Ask for a name (e.g., "MacBook", "iPhone", "Home Server")
   - Ask device type (desktop, mobile, server)
   - Create tunnel:
     ```python
     # Desktop/server
     data = urllib.parse.urlencode({'create_tunnel': '1', 'token': TOKEN, 'name': DEVICE_NAME, 'server': SERVER_NAME}).encode()

     # Mobile
     data = urllib.parse.urlencode({'create_tunnel_mobile': '1', 'token': TOKEN, 'server': SERVER_NAME, 'device_type': 'mobile'}).encode()
     ```
3. List all tunnels to confirm:
   ```python
   data = urllib.parse.urlencode({'list_tunnels': '1', 'token': TOKEN}).encode()
   req = urllib.request.Request(API, data=data, method='POST')
   resp = json.loads(urllib.request.urlopen(req).read())
   # resp['tunnels'] contains name, tunnel_token, assigned_ip, server
   ```
4. Get WireGuard config for each tunnel:
   ```python
   data = urllib.parse.urlencode({'wireguard': '1', 'token': TOKEN, 'tunnel_token': TUNNEL}).encode()
   req = urllib.request.Request(API, data=data, method='POST')
   resp = json.loads(urllib.request.urlopen(req).read())
   # resp['config'] contains WireGuard configuration
   ```

---

## Phase 5: Mesh Networking

**Goal:** Allow tunnels to communicate with each other (private intranet).

1. Ask: "Do you want all your devices to see each other?"
2. **Yes, all (recommended):**
   ```python
   data = urllib.parse.urlencode({'firewall_link_all_toggle': '1', 'token': TOKEN, 'enabled': '1'}).encode()
   ```
3. **Selective:** create specific rules between chosen tunnel pairs:
   ```python
   # Allow Tunnel A to reach Tunnel B (and vice versa)
   data = urllib.parse.urlencode({'firewall_rule_add': '1', 'token': TOKEN, 'tunnel_token': TUNNEL_B, 'protocol': 'ALL', 'src_ip': f'{TUNNEL_A_IP}/32', 'src_port': 'ALL', 'dst_ip': TUNNEL_B_IP, 'dst_port': 'ALL'}).encode()
   # Repeat in reverse for bidirectional access
   ```
4. **No mesh:** skip (tunnels route to internet only)

---

## Phase 6: Custom Domain (optional)

**Goal:** Register a private domain for the network.

1. Ask: "Want to register a private network domain?"
2. Suggest TLDs suited for private networking: `.lan`, `.vpn`, `.mesh`, `.home`, `.wg`, `.wireguard`, `.internal`, `.local`
3. Register:
   ```python
   data = urllib.parse.urlencode({'create_domain': '1', 'token': TOKEN, 'domain': CHOSEN_DOMAIN}).encode()
   ```
4. Create DNS A records pointing to each tunnel's assigned IP:
   ```python
   # e.g., macbook.mynet.lan → 10.1.0.227
   data = urllib.parse.urlencode({'create_dns_record': '1', 'token': TOKEN, 'domain': 'mynet.lan', 'name': 'macbook.mynet.lan', 'type': 'A', 'content': '10.1.0.227', 'ttl': '300'}).encode()
   ```
5. Optionally generate TLS certificate:
   ```bash
   openssl ecparam -genkey -name prime256v1 -out domain.key 2>/dev/null
   openssl req -new -key domain.key -out domain.csr -subj "/CN=mynet.lan" 2>/dev/null
   ```
   ```python
   csr = open('domain.csr').read()
   data = urllib.parse.urlencode({'sign_certificate': '1', 'token': TOKEN, 'domain': 'mynet.lan', 'csr': csr}).encode()
   req = urllib.request.Request(API, data=data, method='POST')
   resp = urllib.request.urlopen(req)
   open('domain.crt', 'wb').write(resp.read())  # Returns raw PEM, not JSON
   ```

---

## Phase 7: DNS Blocking (optional)

**Goal:** Enable ad/tracker/malware blocking.

1. Ask: "Want to enable ad/tracker blocking?"
2. Fetch available blocklists:
   ```python
   data = urllib.parse.urlencode({'dns_get_options': '1'}).encode()
   req = urllib.request.Request(API, data=data, method='POST')
   resp = json.loads(urllib.request.urlopen(req).read())
   # resp['options'] contains name, display_name, category, domain_count
   ```
3. Recommend defaults: ads, tracking, malware
4. Apply to all tunnels:
   ```python
   data = urllib.parse.urlencode({'dns_set_subscription': '1', 'token': TOKEN, 'tunnel_token': TUNNEL, 'subscription': 'ads', 'enabled': '1', 'apply_to_all': '1'}).encode()
   ```

---

## Phase 8: Client Installation

**Goal:** Install WireGuard on each device.

1. Ask: "Which devices do you want to set up now?"
2. For each device, follow the platform-specific guide:
   - **macOS:** Write .conf file, run `wg-quick up doxx`. See `client-guides/macos.md`.
   - **iOS:** Generate QR code, scan in WireGuard app. See `client-guides/ios.md`.
   - **Android:** Generate QR code, scan in WireGuard app. See `client-guides/android.md`.
3. For QR codes (mobile):
   ```python
   data = urllib.parse.urlencode({'generate_qr': '1', 'data': WG_CONF, 'size': '512'}).encode()
   req = urllib.request.Request(API, data=data, method='POST')
   resp = urllib.request.urlopen(req)
   open('qr.png', 'wb').write(resp.read())  # Returns binary PNG, not JSON
   ```

---

## Phase 9: Secure DNS (optional)

**Goal:** Provide DNS blocking on devices not on the tunnel.

1. Ask: "Want DNS blocking on devices that aren't on the tunnel?"
2. Create a Secure DNS hash:
   ```python
   data = urllib.parse.urlencode({'public_dns_create_hash': '1', 'token': TOKEN, 'tunnel_token': TUNNEL}).encode()
   req = urllib.request.Request(API, data=data, method='POST')
   resp = json.loads(urllib.request.urlopen(req).read())
   # resp contains doh_url and dot_host
   ```
3. Provide setup instructions by platform:
   - **iOS:** Settings → General → VPN & Device Management → DNS → DoH URL
   - **Android:** Settings → Network → Private DNS → DoT hostname
   - **Chrome:** Settings → Security → Use secure DNS → Custom DoH URL
   - **Firefox:** Settings → Network → DNS over HTTPS → Custom DoH URL

---

## Phase 10: Verification & Summary

**Goal:** Confirm everything works and provide a summary.

1. Verify auth:
   ```python
   data = urllib.parse.urlencode({'auth': '1', 'token': TOKEN}).encode()
   ```
2. List tunnels, confirm IPs and connection status:
   ```python
   data = urllib.parse.urlencode({'list_tunnels': '1', 'token': TOKEN}).encode()
   ```
3. Check firewall rules:
   ```python
   data = urllib.parse.urlencode({'firewall_rule_list': '1', 'token': TOKEN}).encode()
   ```
4. Verify DNS (if domain registered):
   ```bash
   dig A $DOMAIN @a.root-dx.net +short
   ```
5. Print summary card:
   - Network name / domain
   - Tunnel list with names, IPs, and servers
   - Firewall mode (mesh all / selective / none)
   - DNS blocking status and active blocklists
   - Client setup status per device
   - Recovery codes reminder (if generated)

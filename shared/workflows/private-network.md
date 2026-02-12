# Workflow: Set Up a Private Network

Agent-neutral procedure for building a complete doxx.net private network from scratch. Agents should adapt the prompts and interactions to their native format.

## Variables

- `API` = `https://config.doxx.net/v1/`
- `TOKEN` = user's auth token (obtained in Phase 1)
- `TUNNEL` = tunnel token (obtained in Phase 4)

---

## Phase 1: Authentication

**Goal:** Obtain and validate the user's auth token.

1. Ask user if they have a doxx.net auth token
2. **If yes:** ask them to provide it, then validate:
   ```bash
   curl -s -X POST $API -d "auth=1&token=$TOKEN" | jq .status
   ```
   - If `"success"` → proceed
   - If `"error"` → token is invalid, ask them to check and retry
3. **If no:** explain they must create an account at `https://a0x13.doxx.net`
   - Account creation is human-only (proof-of-work gated)
   - Cannot be done via API — this is by design
   - Offer to wait while they create one

**Important:** The auth token IS the user's identity. There are no usernames or passwords.

---

## Phase 2: Token Storage

**Goal:** Optionally persist the token for future sessions.

1. Ask user if they want to store the token
2. Options:
   - **Environment variable:** add `export DOXX_TOKEN=...` to shell profile
   - **.env file:** write to `.env` in current directory
   - **No storage:** user provides token each time
3. Warn: "This token is your identity. Keep it safe. There are no passwords."
4. Offer to generate recovery codes:
   ```bash
   curl -s -X POST $API -d "create_account_recovery=1&token=$TOKEN" | jq .
   ```
   - Tell user to save the codes somewhere safe
   - These are the only way to recover a lost token

---

## Phase 3: Server Selection

**Goal:** Choose a VPN server location.

1. Fetch server list (no auth needed):
   ```bash
   curl -s -X POST $API -d "servers=1" | jq '.servers[] | {server_name, location, description, continent}'
   ```
2. Present servers grouped by continent
3. Ask user which server is closest to them, or suggest based on context
4. Store selected `SERVER_NAME` for tunnel creation

---

## Phase 4: Tunnel Creation

**Goal:** Create VPN tunnels for each device.

1. Ask: "How many devices will be on this network?"
2. For each device:
   - Ask for a name (e.g., "MacBook", "iPhone", "Home Server")
   - Ask device type (desktop, mobile, server)
   - Create tunnel:
     ```bash
     # Desktop/server
     curl -s -X POST $API -d "create_tunnel=1&token=$TOKEN&name=DEVICE_NAME&server=$SERVER_NAME"

     # Mobile
     curl -s -X POST $API -d "create_tunnel_mobile=1&token=$TOKEN&server=$SERVER_NAME&device_type=mobile"
     ```
3. List all tunnels to confirm:
   ```bash
   curl -s -X POST $API -d "list_tunnels=1&token=$TOKEN" | jq '.tunnels[] | {name, tunnel_token, assigned_ip, server}'
   ```
4. Get WireGuard config for each tunnel:
   ```bash
   curl -s -X POST $API -d "wireguard=1&token=$TOKEN&tunnel_token=$TUNNEL" | jq .config
   ```

---

## Phase 5: Mesh Networking

**Goal:** Allow tunnels to communicate with each other (private intranet).

1. Ask: "Do you want all your devices to see each other?"
2. **Yes, all (recommended):**
   ```bash
   curl -s -X POST $API -d "firewall_link_all_toggle=1&token=$TOKEN&enabled=1"
   ```
3. **Selective:** create specific rules between chosen tunnel pairs:
   ```bash
   # Allow Tunnel A to reach Tunnel B (and vice versa)
   curl -s -X POST $API -d "firewall_rule_add=1&token=$TOKEN&tunnel_token=$TUNNEL_B&protocol=ALL&src_ip=$TUNNEL_A_IP/32&src_port=ALL&dst_ip=$TUNNEL_B_IP&dst_port=ALL"
   curl -s -X POST $API -d "firewall_rule_add=1&token=$TOKEN&tunnel_token=$TUNNEL_A&protocol=ALL&src_ip=$TUNNEL_B_IP/32&src_port=ALL&dst_ip=$TUNNEL_A_IP&dst_port=ALL"
   ```
4. **No mesh:** skip (tunnels route to internet only)

---

## Phase 6: Custom Domain (optional)

**Goal:** Register a private domain for the network.

1. Ask: "Want to register a private network domain?"
2. Suggest TLDs suited for private networking: `.lan`, `.vpn`, `.mesh`, `.home`, `.wg`, `.wireguard`, `.internal`, `.local`
3. Register:
   ```bash
   curl -s -X POST $API -d "create_domain=1&token=$TOKEN&domain=CHOSEN_DOMAIN"
   ```
4. Create DNS A records pointing to each tunnel's assigned IP:
   ```bash
   # e.g., macbook.mynet.lan → 10.1.0.227
   curl -s -X POST $API -d "create_dns_record=1&token=$TOKEN&domain=mynet.lan&name=macbook.mynet.lan&type=A&content=10.1.0.227&ttl=300"
   ```
5. Optionally generate TLS certificate:
   ```bash
   openssl ecparam -genkey -name prime256v1 -out domain.key 2>/dev/null
   openssl req -new -key domain.key -out domain.csr -subj "/CN=mynet.lan" 2>/dev/null
   curl -s -X POST $API -d "sign_certificate=1&token=$TOKEN&domain=mynet.lan" --data-urlencode "csr=$(cat domain.csr)" -o domain.crt
   ```

---

## Phase 7: DNS Blocking (optional)

**Goal:** Enable ad/tracker/malware blocking.

1. Ask: "Want to enable ad/tracker blocking?"
2. Fetch available blocklists:
   ```bash
   curl -s -X POST $API -d "dns_get_options=1" | jq '.options[] | {name, display_name, category, domain_count}'
   ```
3. Recommend defaults: ads, tracking, malware
4. Apply to all tunnels:
   ```bash
   curl -s -X POST $API -d "dns_set_subscription=1&token=$TOKEN&tunnel_token=$TUNNEL&subscription=ads&enabled=1&apply_to_all=1"
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
   ```bash
   curl -s -X POST $API --data-urlencode "generate_qr=1" --data-urlencode "data=$WG_CONF" --data-urlencode "size=512" -o qr.png
   ```

---

## Phase 9: Secure DNS (optional)

**Goal:** Provide DNS blocking on devices not using the VPN.

1. Ask: "Want DNS blocking on devices that aren't on the VPN?"
2. Create a Secure DNS hash:
   ```bash
   curl -s -X POST $API -d "public_dns_create_hash=1&token=$TOKEN&tunnel_token=$TUNNEL" | jq .
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
   ```bash
   curl -s -X POST $API -d "auth=1&token=$TOKEN" | jq .status
   ```
2. List tunnels, confirm IPs and connection status:
   ```bash
   curl -s -X POST $API -d "list_tunnels=1&token=$TOKEN" | jq '.tunnels[] | {name, assigned_ip, server, is_connected}'
   ```
3. Check firewall rules:
   ```bash
   curl -s -X POST $API -d "firewall_rule_list=1&token=$TOKEN" | jq .
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

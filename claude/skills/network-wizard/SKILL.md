---
name: network-wizard
description: Set up a doxx.net private network: tunnels, mesh networking, domains, DNS blocking, and client installation
argument-hint: "[number of devices] [server location]"
user-invocable: true
allowed-tools: Bash(python3 *), Bash(openssl *), Bash(wg-quick *), Bash(dig *), Bash(sudo *), Bash(mkdir *), Bash(tee *), Read, Write
---

# doxx.net Network Wizard

You are an interactive wizard that helps users set up a complete doxx.net private network. Walk the user through each phase, making API calls on their behalf. Be conversational but efficient.

## Key facts

- doxx.net is anonymous by design. No usernames, no passwords, no email. The auth token IS the user's identity.
- You CANNOT create accounts via API. Humans must visit https://a0x13.doxx.net and complete a proof-of-work challenge.
- All Config API calls: `POST https://config.doxx.net/v1/` with `endpoint_name=1` parameter.
- Failover endpoints: `config-us-east.doxx.net`, `config-us-west.doxx.net`, `config-eu-central.doxx.net`
- HTTP 200 can still be an error:always check the `status` field in JSON responses.
- `generate_qr` returns binary PNG, `sign_certificate` returns raw PEM:not JSON.

## Quick start

If the user provided arguments: $ARGUMENTS:parse them for device count and/or server preference, then skip ahead to the relevant phase. If `$DOXXNET_TOKEN` is set in the environment, skip Phase 1-2.

---

## Phase 1: Authentication

Ask: "Do you have a doxx.net auth token?"

**If yes:** ask them to provide it, then validate:
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py auth token=TOKEN_VALUE
```
- `"status": "success"` → proceed
- `"status": "error"` → invalid token, ask to check and retry

**If no:** tell them to create one at https://a0x13.doxx.net (human-only, POW required). Offer to wait.

## Phase 2: Token Storage

Ask: "Want me to store this token for future sessions?"

Options:
- **Shell profile:** append `export DOXXNET_TOKEN=...` to `~/.zshenv`
- **.env file:** write to `.env` in current directory
- **Skip:** user provides token each time

Warn: "This token is your identity. There are no passwords. Keep it safe."

Offer to generate recovery codes:
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py create_account_recovery
```
Tell user to save the returned codes:they're the only way to recover a lost token.

## Phase 3: Server Selection

Fetch servers (no auth needed):
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py servers
```

Present grouped by continent. Ask which server is closest, or suggest based on context.

## Phase 4: Tunnel Creation

Ask: "How many devices will be on this network?"

For each device, ask for a name and type, then create:
```bash
# Desktop/server
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py create_tunnel name=DEVICE_NAME server=SERVER

# Mobile
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py create_tunnel_mobile server=SERVER device_type=mobile
```

List all tunnels to confirm:
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py list_tunnels
```

## Phase 5: Mesh Networking

Ask: "Do you want all your devices to see each other? (recommended for private networks)"

**Yes, all:**
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py firewall_link_all_toggle enabled=1
```

**Selective:** create rules between specific tunnel pairs:
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py firewall_rule_add tunnel_token=TUNNEL_B protocol=ALL src_ip=TUNNEL_A_IP/32 src_port=ALL dst_ip=TUNNEL_B_IP dst_port=ALL
```
(Create bidirectional rules for each pair.)

**No mesh:** skip.

## Phase 6: Custom Domain (optional)

Ask: "Want to register a private network domain?"

Suggest TLDs: `.lan`, `.vpn`, `.mesh`, `.home`, `.wg`, `.wireguard`, `.local`, `.internal`

Register:
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py create_domain domain=DOMAIN
```

Create DNS A records pointing to each tunnel's assigned IP:
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py create_dns_record domain=DOMAIN name=HOSTNAME.DOMAIN type=A content=TUNNEL_IP ttl=300
```

Optionally sign a TLS certificate:
```bash
openssl ecparam -genkey -name prime256v1 -out DOMAIN.key 2>/dev/null
openssl req -new -key DOMAIN.key -out DOMAIN.csr -subj "/CN=DOMAIN" 2>/dev/null
python3 -c "
import urllib.request, urllib.parse, os
token = os.environ['DOXXNET_TOKEN']
csr = open('DOMAIN.csr').read()
data = urllib.parse.urlencode({'sign_certificate': '1', 'token': token, 'domain': 'DOMAIN', 'csr': csr}).encode()
req = urllib.request.Request('https://config.doxx.net/v1/', data=data, method='POST')
resp = urllib.request.urlopen(req)
open('DOMAIN.crt', 'wb').write(resp.read())
"
```

## Phase 7: DNS Blocking (optional)

Ask: "Want to enable ad/tracker blocking on your network?"

Fetch options:
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py dns_get_options
```

Recommend: ads, tracking, malware. Apply:
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py dns_set_subscription tunnel_token=TUNNEL subscription=BLOCKLIST_NAME enabled=1 apply_to_all=1
```

## Phase 8: Client Installation

Ask: "Which devices do you want to set up now?"

For each device, get WireGuard config:
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py wireguard tunnel_token=TUNNEL
```

**macOS:**
```bash
sudo mkdir -p /etc/wireguard
# Write .conf from the config response (extract interface + peer fields)
sudo wg-quick up doxx
```

**iOS/Android:** generate QR code:
```bash
python3 -c "
import urllib.request, urllib.parse, os
token = os.environ['DOXXNET_TOKEN']
wg_conf = 'WG_CONF_STRING_HERE'
data = urllib.parse.urlencode({'generate_qr': '1', 'data': wg_conf, 'size': '512'}).encode()
req = urllib.request.Request('https://config.doxx.net/v1/', data=data, method='POST')
resp = urllib.request.urlopen(req)
open('doxx-qr.png', 'wb').write(resp.read())
"
```
Tell user to scan with WireGuard app.

For detailed per-platform steps, read the guides in `shared/client-guides/`.

## Phase 9: Secure DNS (optional)

Ask: "Want DNS blocking on devices that aren't on the tunnel?"

Create Secure DNS hash:
```bash
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py public_dns_create_hash tunnel_token=TUNNEL
```

Provide setup instructions:
- **iOS:** Settings → General → VPN & Device Management → DNS → add DoH URL
- **Android:** Settings → Network → Private DNS → enter DoT hostname
- **Chrome:** Settings → Security → Use secure DNS → Custom → DoH URL
- **Firefox:** Settings → Network → DNS over HTTPS → Custom → DoH URL

## Phase 10: Verification & Summary

Verify everything:
```bash
# Auth
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py auth

# Tunnels
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py list_tunnels

# Firewall
python3 ~/.claude/plugins/cache/doxx-skills/doxxnet/*/scripts/doxx-api.py firewall_rule_list

# DNS (if domain registered)
dig A DOMAIN @a.root-dx.net +short
```

Print a summary card with:
- Network name / domain
- Tunnel list (name, IP, server)
- Firewall mode (mesh all / selective / none)
- DNS blocking (active blocklists)
- Client setup status per device
- Recovery codes reminder

---

## Behavior guidelines

- **Be idempotent:** before creating anything, check if it already exists (list_tunnels, list_domains, firewall_rule_list)
- **Be recoverable:** if the wizard is interrupted, check existing state and resume from where things left off
- **Never ask for email/name/identity** unless the user volunteers it
- **Always validate API responses:** check `status` field, show errors clearly
- **Handle failover:** if the primary API endpoint fails, try regional endpoints

For full API details, see [../../../api/reference.md](../../../api/reference.md).

---
name: network-wizard
description: "Set up a doxx.net private network: tunnels, mesh networking, domains, DNS blocking, and client installation"
version: 1.0.0
homepage: https://github.com/doxxcorp/doxx-skills
user-invocable: true
metadata.openclaw: {"env": ["DOXXNET_TOKEN"], "bins": ["curl", "openssl", "dig", "wg-quick"], "primaryEnv": "DOXXNET_TOKEN"}
---

# doxx.net Network Wizard

You are an interactive wizard that helps users set up a complete doxx.net private network. Walk the user through each phase, making API calls on their behalf. Be conversational but efficient.

## Key facts

- doxx.net is anonymous by design. No usernames, no passwords, no email. The auth token IS the user's identity.
- You CANNOT create accounts via API. Humans must visit https://a0x13.doxx.net and complete a proof-of-work challenge.
- HTTP 200 can still be an error — always check the `status` field in JSON responses.

## API convention

Token is provided via `$DOXXNET_TOKEN` environment variable.

**Config API** — POST to `https://config.doxx.net/v1/` with URL-encoded form data:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=$DOXXNET_TOKEN"
```

**Stats API** — POST to `https://secure-wss.doxx.net/api/stats/` with `X-Auth-Token` header:
```
curl -s -X POST https://secure-wss.doxx.net/api/stats/ENDPOINT -H "X-Auth-Token: $DOXXNET_TOKEN" -d "param=value"
```

**Special responses:** `sign_certificate` returns raw PEM (not JSON). `generate_qr` returns binary PNG — use `curl -s ... -o file.png`.

## Quick start

If the user provided arguments: $ARGUMENTS — parse them for device count and/or server preference, then skip ahead to the relevant phase. If `$DOXXNET_TOKEN` is already set and valid, skip Phase 1.

---

## Phase 1: Authentication

Validate `$DOXXNET_TOKEN`: `curl -s -X POST https://config.doxx.net/v1/ -d "auth=1&token=$DOXXNET_TOKEN"`

If `$DOXXNET_TOKEN` is not set or validation fails, tell the user to run `export DOXXNET_TOKEN=your-token` and try again.

**If the user doesn't have a token yet:** tell them to create one at https://a0x13.doxx.net (human-only, POW required). Offer to wait.

Warn: "This token is your identity. There are no passwords. Keep it safe."

Offer to generate recovery codes with the `create_account_recovery` endpoint.

## Phase 2: Server Selection

Fetch servers (no auth needed): `curl -s -X POST https://config.doxx.net/v1/ -d "servers=1"`

Present grouped by continent. Ask which server is closest, or suggest based on context.

## Phase 3: Tunnel Creation

Ask: "How many devices will be on this network?"

For each device, ask for a name and type, then create:
- Desktop/server: `curl -s -X POST ... -d "create_tunnel=1&server=HOST&name=NAME&token=$DOXXNET_TOKEN"`
- Mobile: `curl -s -X POST ... -d "create_tunnel_mobile=1&server=HOST&name=NAME&device_type=mobile&token=$DOXXNET_TOKEN"`

List all tunnels to confirm: `list_tunnels=1`

## Phase 4: Mesh Networking

Ask: "Do you want all your devices to see each other? (recommended for private networks)"

**Yes, all:** `firewall_link_all_toggle=1&enabled=1`
**Selective:** `firewall_rule_add=1` between specific tunnel pairs (bidirectional)
**No mesh:** skip.

## Phase 5: Custom Domain (optional)

Ask: "Want to register a private network domain?"

Suggest TLDs: `.lan`, `.vpn`, `.mesh`, `.home`, `.wg`, `.wireguard`, `.local`, `.internal`

Register with `create_domain=1&domain=NAME`, then create DNS A records with `create_dns_record=1` pointing to each tunnel's assigned IP.

Optionally sign a TLS certificate with openssl + `sign_certificate=1&domain=DOMAIN&csr=PEM`.

## Phase 6: DNS Blocking (optional)

Ask: "Want to enable ad/tracker blocking on your network?"

Fetch options (no auth): `dns_get_options=1`. Recommend: ads, tracking, malware.

Apply with `dns_set_subscription=1&tunnel_token=TT&blocklist_name=NAME&enabled=1&apply_to_all=1`.

## Phase 7: Client Installation

Ask: "Which devices do you want to set up now?"

For each device, get config with `wireguard=1&tunnel_token=TT`, build a .conf file.

**macOS:** Write the config to `/etc/wireguard/doxx.conf` using shell commands, then run `sudo wg-quick up doxx`
**iOS/Android:** Generate QR code with `curl -s -X POST ... -d "generate_qr=1&data=CONFIG" -o doxx-qr.png`, scan in WireGuard app

## Phase 8: Secure DNS (optional)

Ask: "Want DNS blocking on devices that aren't on the tunnel?"

Create hash with `public_dns_create_hash=1&tunnel_token=TT`, provide setup instructions per platform.

## Phase 9: Verification & Summary

Verify with `auth=1`, `list_tunnels=1`, `firewall_rule_list=1`.

Print a summary card with:
- Network name / domain
- Tunnel list (name, IP, server)
- Firewall mode (mesh all / selective / none)
- DNS blocking (active blocklists)
- Client setup status per device
- Recovery codes reminder

---

## Behavior guidelines

- **Be idempotent:** before creating anything, check if it already exists
- **Be recoverable:** if the wizard is interrupted, check existing state and resume
- **Never ask for email/name/identity** unless the user volunteers it
- **Always validate API responses:** check `status` field, show errors clearly

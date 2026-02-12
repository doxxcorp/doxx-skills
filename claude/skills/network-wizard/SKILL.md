---
name: network-wizard
description: Set up a doxx.net private network: tunnels, mesh networking, domains, DNS blocking, and client installation
argument-hint: "[number of devices] [server location]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(openssl *), Bash(wg-quick *), Bash(dig *), Bash(sudo *), Read, Write
---

# doxx.net Network Wizard

You are an interactive wizard that helps users set up a complete doxx.net private network. Walk the user through each phase, making API calls on their behalf. Be conversational but efficient.

## Key facts

- doxx.net is anonymous by design. No usernames, no passwords, no email. The auth token IS the user's identity.
- You CANNOT create accounts via API. Humans must visit https://a0x13.doxx.net and complete a proof-of-work challenge.
- HTTP 200 can still be an error — always check the `status` field in JSON responses.

## API convention

Token file: `~/.config/doxxnet/token`

**IMPORTANT — avoiding permission prompts:**
- To read the token: use the `Read` tool on `~/.config/doxxnet/token`. Remember the token value and use it directly in curl commands below (substitute TOKEN with the actual value).
- To save a token: use the `Write` tool to `~/.config/doxxnet/token`
- NEVER use Bash for file operations — only `Read` and `Write` tools. Bash is ONLY for `curl` commands.

**Config API** — POST to `https://config.doxx.net/v1/` with URL-encoded form data:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=TOKEN"
```

**Stats API** — GET from `https://secure-wss.doxx.net/api/stats/`:
```
curl -s "https://secure-wss.doxx.net/api/stats/ENDPOINT?token=TOKEN&param=value"
```

Replace TOKEN with the actual token value read from the file. Do NOT use `$(cat ...)` or any subshell.

**Special responses:** `sign_certificate` returns raw PEM (not JSON). `generate_qr` returns binary PNG — use `curl -s ... -o file.png`.

## Quick start

If the user provided arguments: $ARGUMENTS — parse them for device count and/or server preference, then skip ahead to the relevant phase. If `~/.config/doxxnet/token` exists, skip Phase 1.

---

## Phase 1: Authentication

Use the `Read` tool on `~/.config/doxxnet/token` to check if a token exists. If it does, validate: `curl -s -X POST https://config.doxx.net/v1/ -d "auth=1&token=TOKEN"` (substitute the actual token value)

If no token or validation fails, ask: "Do you have a doxx.net auth token?"

**If yes:** validate with `curl -s -X POST https://config.doxx.net/v1/ -d "auth=1&token=THEIR_TOKEN"`. On success, save it with the `Write` tool to `~/.config/doxxnet/token`.
**If no:** tell them to create one at https://a0x13.doxx.net (human-only, POW required). Offer to wait.

Warn: "This token is your identity. There are no passwords. Keep it safe."

Offer to generate recovery codes with the `create_account_recovery` endpoint.

## Phase 2: Server Selection

Fetch servers (no auth needed): `curl -s -X POST https://config.doxx.net/v1/ -d "servers=1"`

Present grouped by continent. Ask which server is closest, or suggest based on context.

## Phase 3: Tunnel Creation

Ask: "How many devices will be on this network?"

For each device, ask for a name and type, then create:
- Desktop/server: `curl -s -X POST ... -d "create_tunnel=1&server=HOST&name=NAME&token=..."`
- Mobile: `curl -s -X POST ... -d "create_tunnel_mobile=1&server=HOST&name=NAME&device_type=mobile&token=..."`

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

Apply with `dns_set_subscription=1&tunnel_token=TT&subscription=NAME&enabled=1&apply_to_all=1`.

## Phase 7: Client Installation

Ask: "Which devices do you want to set up now?"

For each device, get config with `wireguard=1&tunnel_token=TT`, build a .conf file.

**macOS:** Write to `/etc/wireguard/doxx.conf`, run `sudo wg-quick up doxx`
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

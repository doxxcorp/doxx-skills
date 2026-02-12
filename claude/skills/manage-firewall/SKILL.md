---
name: manage-firewall
description: Manage doxx.net firewall rules — open ports, link tunnels for mesh networking, manage access rules
argument-hint: "[action] [details]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(jq *), Read
---

# Manage doxx.net Firewall

You help users manage firewall rules on their doxx.net tunnels. This controls which tunnels can talk to each other (mesh networking) and which ports are open to the internet.

## Setup

```bash
API="https://config.doxx.net/v1/"
```

Use `$DOXX_TOKEN` if set, otherwise ask for the auth token.

User request: $ARGUMENTS

## Available operations

### List firewall rules
```bash
curl -s -X POST $API -d "firewall_rule_list=1&token=$TOKEN" | jq .
```

Returns `link_all_enabled` (mesh status), `rules[]`, and `count`.

Filter by tunnel:
```bash
curl -s -X POST $API -d "firewall_rule_list=1&token=$TOKEN&tunnel_token=$TUNNEL" | jq .
```

### Link all tunnels (mesh networking)

Enable — every tunnel can reach every other tunnel on the account:
```bash
curl -s -X POST $API -d "firewall_link_all_toggle=1&token=$TOKEN&enabled=1"
```

Disable:
```bash
curl -s -X POST $API -d "firewall_link_all_toggle=1&token=$TOKEN&enabled=0"
```

Check status:
```bash
curl -s -X POST $API -d "firewall_link_all_status=1&token=$TOKEN" | jq .
```

### Add a firewall rule

Open a port to the internet:
```bash
# Open TCP port 443 on a tunnel to all sources
curl -s -X POST $API -d "firewall_rule_add=1&token=$TOKEN&tunnel_token=$TUNNEL&protocol=TCP&src_ip=0.0.0.0/0&src_port=ALL&dst_ip=$TUNNEL_IP&dst_port=443"
```

Allow specific tunnel-to-tunnel access (selective mesh):
```bash
# Allow Tunnel A (10.1.0.100) to reach Tunnel B (10.1.2.50) on all ports
curl -s -X POST $API -d "firewall_rule_add=1&token=$TOKEN&tunnel_token=$TUNNEL_B_TOKEN&protocol=ALL&src_ip=10.1.0.100/32&src_port=ALL&dst_ip=10.1.2.50&dst_port=ALL"

# Bidirectional: also allow B to reach A
curl -s -X POST $API -d "firewall_rule_add=1&token=$TOKEN&tunnel_token=$TUNNEL_A_TOKEN&protocol=ALL&src_ip=10.1.2.50/32&src_port=ALL&dst_ip=10.1.0.100&dst_port=ALL"
```

Parameters:
- `protocol`: `TCP`, `UDP`, `ICMP`, or `ALL`
- `src_ip`: source IP/CIDR (use `0.0.0.0/0` for any)
- `src_port`: source port or `ALL`
- `dst_ip`: destination (your tunnel's assigned IP)
- `dst_port`: destination port or `ALL`

### Delete a firewall rule
```bash
curl -s -X POST $API -d "firewall_rule_delete=1&token=$TOKEN&tunnel_token=$TUNNEL&protocol=TCP&src_ip=0.0.0.0/0&src_port=ALL&dst_ip=$TUNNEL_IP&dst_port=443"
```

Same parameters as `firewall_rule_add`.

## Common patterns

**Home server accessible from all devices:**
1. Enable link-all: `firewall_link_all_toggle=1&enabled=1`
2. Open specific ports to internet if needed (e.g., 443 for web server)

**Only laptop + phone can see each other:**
1. Keep link-all disabled
2. Add bidirectional rules between the two tunnels

**Open SSH on a server tunnel:**
```bash
curl -s -X POST $API -d "firewall_rule_add=1&token=$TOKEN&tunnel_token=$TUNNEL&protocol=TCP&src_ip=0.0.0.0/0&src_port=ALL&dst_ip=$TUNNEL_IP&dst_port=22"
```

## Guidelines

- Always list current rules before making changes
- Get tunnel IPs from `list_tunnels` — you need the `assigned_ip` for rules
- For mesh networking between two tunnels, always create bidirectional rules (A→B and B→A)
- Confirm with the user before deleting rules
- Prefer link-all over manual rules when the user wants full mesh

For full API details, see [../../../api/reference.md](../../../api/reference.md).

---
name: manage-firewall
description: Manage doxx.net firewall rules: open ports, link tunnels for mesh networking, manage access rules
argument-hint: "[action] [details]"
user-invocable: true
---

# Manage doxx.net Firewall

You help users manage firewall rules on their doxx.net tunnels. This controls which tunnels can talk to each other (mesh networking) and which ports are open to the internet.

Use the doxxnet MCP tools for all API calls. If the token is not configured, ask the user for their auth token.

User request: $ARGUMENTS

## Available MCP tools

- `doxx_firewall_list` — list all firewall rules (optionally filter by tunnel_token)
- `doxx_firewall_add` — add a rule (tunnel_token, protocol, src_ip, src_port, dst_ip, dst_port)
- `doxx_firewall_delete` — delete a rule (same params as add)
- `doxx_firewall_link_all` — toggle mesh networking (enabled: 1 or 0)
- `doxx_firewall_link_status` — check if mesh networking is enabled
- `doxx_list_tunnels` — list tunnels (to get assigned IPs for rules)

## Common patterns

**Home server accessible from all devices:**
1. Enable link-all with `doxx_firewall_link_all` (enabled=1)
2. Open specific ports to internet if needed (e.g., 443 for web server)

**Only laptop + phone can see each other:**
1. Keep link-all disabled
2. Add bidirectional rules between the two tunnels

**Open SSH on a server tunnel:**
- `doxx_firewall_add` with protocol=TCP, src_ip=0.0.0.0/0, src_port=ALL, dst_ip=TUNNEL_IP, dst_port=22

## Guidelines

- Always list current rules before making changes
- Get tunnel IPs from `doxx_list_tunnels` — you need the `assigned_ip` for rules
- For mesh networking between two tunnels, always create bidirectional rules (A→B and B→A)
- Confirm with the user before deleting rules
- Prefer link-all over manual rules when the user wants full mesh

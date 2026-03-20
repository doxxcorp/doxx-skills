---
name: manage-addresses
description: "Manage doxx.net IP addresses and saved profiles: assign, release, rotate IPs, lease dedicated IPv4, create and manage connection profiles"
argument-hint: "[action] [address or profile]"
user-invocable: true
allowed-tools: Bash(curl *), Read, Write
---

# Manage doxx.net Addresses & Profiles

You help users manage their doxx.net IP addresses and saved connection profiles.

User request: $ARGUMENTS

## API convention

Token file: `~/.config/doxxnet/token`

**IMPORTANT: avoiding permission prompts:**
- To read the token: use the `Read` tool on `~/.config/doxxnet/token`. Remember the token value and use it directly in curl commands below (substitute TOKEN with the actual value).
- To save a token: use the `Write` tool to `~/.config/doxxnet/token`
- NEVER use Bash for file operations: only `Read` and `Write` tools. Bash is ONLY for `curl` commands.

If missing or auth fails, ask the user for their token, validate with `auth=1&token=THEIR_TOKEN`, and save it with the `Write` tool.

**Config API**: POST to `https://config.doxx.net/v1/`:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=TOKEN"
```

Replace TOKEN with the actual token value read from the file. Do NOT use `$(cat ...)` or any subshell.

## IP Address Endpoints

- `list_addresses`: list all assigned IPs. Returns `addresses[]` with: address, type (static_public/static_private/static_ipv6), site_id, location, profile_id, profile_name, tunnel_token, tunnel_name, connected, device_name, persistent
- `assign_address`: assign IP to a profile. Params: `address`, `type`. Optional: `profile_id` (omit to unassign)
- `release_address`: release an assigned IP. Params: `address`, `type`
- `rotate_address`: rotate to a new IP (releases current, assigns new). Params: `address`, `type`
- `lease_public_ipv4`: lease a dedicated public IPv4. Params: `profile_name`, `profile_icon`, `profile_type` (wireguard), `server`. Optional: `ip_type` (ipv6), `include_ipv6` (1)

## Saved Profile Endpoints

- `list_saved_profiles`: list all profiles. Returns `profiles[]` with: profile_id, profile_name, profile_icon, profile_type (ios/wireguard/android), preferred_server, domain_name, created_at, updated_at, ipv4_public_enabled, onion_enabled, proxy_enabled, ip_locked, settings_locked, in_use, in_use_by, in_use_device_icon, source_tunnel_name
- `create_saved_profile`: create a profile. Params: `profile_name`, `profile_icon`, `profile_type` (wireguard), `server`
- `update_saved_profile`: update settings. Params: `profile_id`. Optional: `profile_icon`, `profile_name`, `preferred_server`
- `delete_saved_profile`: delete. Params: `profile_id`
- `load_profile`: apply a profile to a tunnel. Params: `tunnel_token`, `profile_id`

## Context Endpoints

- `list_tunnels`: list tunnels (for tunnel tokens when applying profiles)
- `servers`: list available servers (for profile creation and IP leasing, no auth needed)

## Address Types

| Type | Description |
|------|-------------|
| `static_public` | Dedicated public IPv4 address |
| `static_private` | Static private network address |
| `static_ipv6` | Static IPv6 address |

## Guidelines

- Always list current addresses/profiles before making changes
- When leasing public IPv4, explain it's a dedicated IP that persists across reconnections
- When rotating, warn that the old IP is released and a new one assigned
- Confirm before releasing addresses (especially persistent/dedicated ones)
- Show which profiles are in_use and by which tunnel/device
- When creating profiles, list available servers for the user to choose
- Group addresses by type when presenting
- Always check API response `status` field: HTTP 200 can still be an error

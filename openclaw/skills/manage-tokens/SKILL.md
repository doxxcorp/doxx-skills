---
name: manage-tokens
description: "Manage doxx.net auth tokens: create, revoke, update roles, set geo/IP fences, and scope tokens to specific tunnels"
version: 1.0.0
homepage: https://github.com/doxxcorp/doxx-skills
user-invocable: true
metadata.openclaw: {"env": ["DOXXNET_TOKEN"], "bins": ["curl"], "primaryEnv": "DOXXNET_TOKEN"}
---

# Manage doxx.net Tokens

You help users manage their doxx.net auth tokens: create scoped tokens for agents or team members, revoke compromised tokens, set expiration, restrict by country or IP, and limit to specific tunnels.

User request: $ARGUMENTS

## API convention

Token is provided via `$DOXXNET_TOKEN` environment variable.

**Config API**: POST to `https://config.doxx.net/v1/`:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=$DOXXNET_TOKEN"
```

Most token management endpoints require **admin** role. `list_tokens` is available to all roles.

## Endpoints

### Listing
- `list_tokens`: list all tokens for the account. Returns: `tokens[]` with `token_preview`, `label`, `role`, `created_at`, `expires_at`, `revoked_at`, `is_current`, `geo_fence[]`, `ip_fence[]`, `tunnel_scope[]`

### Creating and updating (admin only)
- `create_token`: create a new token. Optional params: `label` (max 64 chars), `role` (`admin`/`net-admin`/`read-only`, default `admin`), `expires_at` (RFC3339). Returns: `new_token` (shown once, store securely)
- `update_token`: update label, role, or expiry. Params: `target_token` (required), optional: `label`, `role`, `expires_at` (RFC3339 or `never`). Can reactivate expired tokens.
- `revoke_token`: revoke immediately. Params: `target_token` (required). Cannot revoke your own active token. Revoked tokens appear in `list_tokens` with `revoked_at` set.

### Geo fencing (admin only)
When a token has geo fence entries, it can only be used from those countries (GeoIP lookup).
- `add_geo_fence`: params: `target_token`, `country` (ISO 3166-1 alpha-2, e.g. `US`). Optional: `label`
- `remove_geo_fence`: params: `target_token`, `country`. Removing all entries removes the restriction.

### IP fencing (admin only)
When a token has IP fence entries, it can only be used from matching IPs/CIDRs.
- `add_ip_fence`: params: `target_token`, `cidr` (IPv4/IPv6 address or CIDR, e.g. `203.0.113.0/24`). Optional: `label`. Bare IPs normalized to /32 or /128.
- `remove_ip_fence`: params: `target_token`, `cidr` (must match stored value exactly). Removing all entries removes the restriction.

### Tunnel scoping (admin only)
When a token has tunnel scope entries, it can only view and modify those tunnels.
- `add_token_tunnel`: params: `target_token`, `tunnel_token` (must be owned by the account). Optional: `label`
- `remove_token_tunnel`: params: `target_token`, `tunnel_token`. Removing all entries restores full tunnel access.

## Roles

| Role | Can do |
|------|--------|
| `admin` | Everything, including token management |
| `net-admin` | All tunnel/network operations, no token management |
| `read-only` | Read-only access to all resources |

## Guidelines

- Always call `list_tokens` first to show the current token landscape before making changes
- When creating tokens for AI agents or automation: suggest `net-admin` role + expiration + IP fence for least privilege
- Strongly warn users when they revoke a token that is currently in use (they will need to update their configuration)
- `new_token` from `create_token` is shown only once -- remind users to store it securely before moving on
- When a user asks to "rotate" their token: create a new admin token first, then revoke the old one in that order
- Suggest tunnel scoping for tokens given to users who should only access specific tunnels
- Suggest IP fencing for tokens used from known fixed IPs (servers, CI systems)
- For geo fencing: note that GeoIP lookup failure allows the request by default
- Always check API response `status` field -- HTTP 200 can still be an error

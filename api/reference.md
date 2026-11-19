# doxx.net API Reference (Agent-Optimized)

**Config API version: 1.1.0** (live manifest), synced against the live manifest on 2026-11-17. This file is a snapshot: the live API self-documents. `curl -s https://config.doxx.net/` (a GET, no token) returns the current manifest (every endpoint with params, returns, auth, min role and side effects, plus `use_cases` recipes), and every API response carries a `context` field with per-endpoint help. Where this file and the manifest disagree, the entries below follow the handler code: see "Known manifest errors" at the end.

How to use it: one entry per endpoint, grouped like the manifest (`.endpoints`): purpose, **Role** (minimum token role), params, returns, gates (plan features, limits) and side effects. Plan names: Free, Essentials (API slug `basic`), Pro. Pro+ is legacy, not sold. Never quote seat counts, limits or prices from memory: read them live (see "Plans and entitlements").

## Calling the API

All Config API calls are `POST https://config.doxx.net/v1/` with `application/x-www-form-urlencoded` params. The endpoint is selected by `<endpoint>=1`; the account token goes in as `token`. Responses are JSON with `status` `success` or `error`: HTTP 200 can still be an error, so always check `status`.

Every example below calls `doxx`, a shell function that sends the token and every param to curl as a config on stdin (`curl -K -`), so no token and no param value (a `tunnel_token` included) ever appears in a command line. Each shell call starts fresh, so define it in the same command as the call (the definition is the same as the one in the skills' "Calling the API" section: `DOXX_TOKEN` env, then `~/.config/doxx/token`, then the legacy `DOXXNET_TOKEN` / `~/.config/doxxnet/token`):

```
doxx() { { printf 'url=https://config.doxx.net/v1/\ndata-urlencode=token=%s\n' "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}"; while [ $# -ge 2 ]; do case "$1" in -d) printf 'data=%s\n' "$2" ;; *) printf '%s=%s\n' "${1#--}" "$2" ;; esac; shift 2; done; } | awk -v n=$(($# / 2 + 2)) '{s = ""; for (i = 1; i <= length($0); i++) {c = substr($0, i, 1); s = s (c == "\\" || c == "\"" ? "\\" : "") c}; k = index(s, "="); o = o substr(s, 1, k - 1) " = \"" substr(s, k + 1) "\"\n"} END {if (NR == n) printf "%s", o}' | curl -s -K - -X POST; }
doxx -d "list_domains=1"
```

- Pass params to `doxx` as `-d "endpoint=1&a=b"`, and values that may hold spaces or symbols (JSON, PEM, config text) as `--data-urlencode "name=value"` (or `"name@file"`). Each pair becomes one curl config line, with `\` and `"` escaped. A value that holds a line break would add a config line of its own, so then the `awk` line count does not match, nothing is written, and curl sends nothing (it has no URL). A multi-line value, such as a PEM, must go in as `"name@file"`. `doxx` takes only `-d` and long `--option value` pairs.
- `TUNNEL_TOKEN` and `TARGET_TOKEN` in the examples stand for a shell variable such as `$tt` that the shell fills in from a `jq` lookup (`list_tunnels`, `user_list_tokens`): never type a token value into a command.
- Never echo, print or log the token. `tunnel_token` values are credentials too: refer to tunnels by name and never print them. `list_tunnels` returns every tunnel's `private_key` and `tunnel_token`; `user_list_tokens` returns full token strings. Always pipe such answers through `jq` selecting only the fields you show.
- If doxx MCP tools are available in the session (tool names equal endpoint names), they may be used instead of curl: the server injects the token. Everything else here applies the same way.
- Other token carriers the API accepts (a `doxx_token` cookie, an `X-Auth` header) are for browsers and the apps; use the `token` param.
- Booleans are `1` or `0` (`true` is accepted by most handlers).
- Regional endpoints (same `/v1/` path, same data): `config.doxx.net` (round robin, default), `config-us-east.doxx.net`, `config-us-west.doxx.net`, `config-eu-central.doxx.net`.

Roles are hierarchical: `admin` includes `net-admin`, which includes `read-only`. A fourth role, `device`, is a gateway credential bound to one tunnel (it can call `auth`, fetch that tunnel's WireGuard config and read its firewall rules; everything else is refused). **Role** below is the minimum role; "any" means every role. A role that is too low answers `insufficient_role`.

### auth
Check a token: the cheapest way to see that a token works before anything else. No side effects.
```
doxx -d "auth=1"
```
Returns `status`, `message` ("Authentication successful") and `role` (the token's role: `admin`, `net-admin`, `read-only`, `device`). **Role:** any. Prints nothing secret. A bad or expired token fails every call, so run this first when a call answers an authentication error.

## Errors

An error has `status: "error"` and a `message`. Read the `context` field too, when present. Most structured errors name themselves in `error_code`; two use the key `error` instead (marked below). Note the HTTP codes: one of them arrives with HTTP 200.

| Code | HTTP | Key fields | What to do |
|---|---|---|---|
| `feature_required` | 403 | `feature`, `feature_display`, `field`, `plan`, `upgrade_url` | The plan does not include this feature. Tell the user what is locked. Do not retry with other values to get around it. |
| `feature_required` with `feature: "connect"` | 403 | `account_status`, `plan`, `fix`, `upgrade_url` | The account is paused, expired or revoked. The user fixes it in the portal (revoked: support@doxx.net). |
| `seat_limit` | 409 | `seated_devices`, `total_seats`, `my_device_seated`, `fix`, `upgrade_url`, `devices_url` | Every device seat is in use. Offer to list devices (`device_list_unified`) so the user can pick one to remove. Adding seats is their decision, in the portal. |
| `agent_limit` | 403 | `limit`, `used`, `max`, `upgrade_url` | All agent seats are in use. The user removes an agent or adds agent seats. |
| `domain_limit` | 403 | `limit`, `used`, `max`, `upgrade_url` | Each domain past the ones the plan includes is an add-on. The user adds it in the portal, then you retry. |
| `vps_limit` | 409 | `component`, `available`, `needed`, `monthly_usd`, `fix`, `upgrade_url` | The VPS add-on lacks that resource. Offer a smaller shape, or the user adds capacity. Here `upgrade_url` is a path on the portal (https://app.doxx.net): show it as given and say so. |
| `vps_firewall_limit` | 409 | `used`, `max`, `fix`, `upgrade_url` | A cloud server already holds its plan's cap of firewall rules (the default ICMP rules do not count). Show `fix`: the user removes a rule or moves to a plan with a higher cap. `upgrade_url` is a portal path, as for `vps_limit`. |
| `dedicated_ip_limit` (key `error`) | 200 | `current_count`, `max_slots`, `existing_allocation` | Every dedicated IPv4 slot is in use. `existing_allocation` names the IP and server that hold it and carries a `tunnel_token`: name that tunnel, never print the token. |
| `insufficient_role` (key `error`) | 403 | `required_role`, `your_role` | The token's role is too low for this call. Ask the user for a token with the named role. Do not look for a way around it. |
| (none: HTTP 423, profile lock) | 423 | `lock_type` (`settings` or `ip`), `profile_id`, `profile_name`; a settings lock also has `in_use`, `in_use_by` (device name) | The tunnel's saved profile is locked against this change. Show `message` and name the profile. Do not unlock it on your own: ask the user first (`unlock_profile` with that `lock_type`). With `in_use: true` the profile is live on `in_use_by`: that device must disconnect from it or switch profiles first. |

Any other error: a plain `message`, often with `context` and a `fix`. Other status codes seen across endpoints: 400 (bad or missing param), 403 (not your tunnel, domain or agent), 404, 409 (conflict, duplicate or limit), 410 (retired endpoint or field), 423 (profile lock), 429 (rate limit), 5xx (retry later). The `upgrade_url` and `fix` values name the portal usually as https://app.doxx.net and sometimes as `a0x13.doxx.net`, the same portal under its other name (`seat_limit`, `agent_limit`, `domain_limit` and some `feature_required` answers); the cloud server ones are bare portal paths. Show them verbatim either way.

Rules:

- Show `message`, `fix` and `upgrade_url` to the user verbatim. They are written for people.
- Never buy, subscribe, upgrade or add seats or add-ons on the user's behalf, even if a `fix` names a payments endpoint that would do it. Explain the options and let the user act in the portal.
- Do not retry a limit or plan error in a loop. It will not change until the user changes the plan or frees a resource.

## Plans and entitlements

Plan, seats and features are live data, never fixed numbers. This account: `POST https://payments.doxx.net/v1/access/status` with the token (stdin, as above). The answer is under `access`: `plan`, `status`, `total_seats`, `seated_devices`, `features` (name to true/false), `limits` (name to `used`/`max`). Public price list (no token): `curl -s https://payments.doxx.net/v1/pricing` returns `plans`, `addons` and a feature `comparison`. Plan changes, seats and add-ons are the user's decision, in the portal at https://app.doxx.net/ops/account/subscription. Accounts cannot be created through the API, and neither can recovery codes: both are managed in the portal (https://app.doxx.net).

---

## Account (group `account`)

### get_profile
Read the account profile. **Role:** any.
```
doxx -d "get_profile=1"
```
Returns `profile` (`recovery_email`, `recovery_phone`: `null` when unset; `email_notifications`, `sms_notifications`: 0 or 1; `created_at`, `updated_at`) and `recovery_codes_count` (unused recovery codes). Recovery contacts are opt-in; doxx.net does not need them.

### update_profile
Set the recovery contacts and notification switches. **Role:** admin. A partial update: only the fields you send are written.
```
doxx -d "update_profile=1&recovery_email=me@example.com"
```
Params, each optional: `recovery_email` (must contain `@`, max 254 chars), `recovery_phone` (international format `+1234567890`, 7 to 15 digits, separators are stripped; URL-encode the `+` as `%2B`), `email_notifications`, `sms_notifications` (`1` or `0`). A field you leave out keeps its stored value. An empty `recovery_email` or `recovery_phone` clears that contact; `0` turns a notification off. A call with none of the four fields answers 400. Returns a confirmation message.

### delete_account
Permanently delete the account and everything it holds: tunnels and addresses, domains and records, DNS and firewall settings, proxy configs, devices, saved profiles, owned bots, tokens, recovery codes and chat-side data (friends, agents). **Role:** admin.
```
doxx -d "delete_account=1"
```
Irreversible. Every active tunnel disconnects at once on all edge servers; any subscription is cancelled. Needs the user's explicit confirmation in the same conversation.

## Agents (group `agents`)

Agent principals are chat identities owned by the account: an owned sub-friend, not a separate user, token or billing entity. The agent binds to one of the account's devices through `create_token role=device` and is hosted by the doxxGateway binary (https://github.com/doxxcorp/gateway) on Linux, or the in-app gateway on macOS. See the `chat_bot_gateway_for_ai_agents` recipe in the live manifest's `use_cases`.

### create_agent
Create an agent principal. **Role:** net-admin.
```
doxx -d "create_agent=1&agent_name=Fable"
```
Params: `agent_name` (required, max 64 chars: the friend name the devices show). Optional: `kind` (`agent` default, a dedicated-machine gateway; `device_agent`, the in-app gateway sharing one of your device seats; `webhook`, a post-only receiver hosted on one of your devices), `a2a_enabled=1` (agent-to-agent chat, off by default and needed on both agents). Returns `agent_id`, `agent_name`, `kind`, `a2a_enabled`, `notes`. New agents start OWNER-ONLY (`owner_only` 1): they reach the owner and nobody else until the owner unlocks friend links; every link is then double opt-in. The agent is paired to you as a friend at once. No token is minted.
Gates: `feature_required` with `feature: "agents"` (no agents on this plan) or `"p2p"` (no chat at all, for example a paused account), `agent_limit` (all agent seats used), 400 "Set your profile name before creating an agent".

### list_agents
List the agents the account owns (the directory only). **Role:** any.
```
doxx -d "list_agents=1"
```
Returns `agents[]`: `agent_id`, `agent_name`, `kind`, `a2a_enabled`, `owner_only` (booleans), `status`, `bound` (has a host), `credentials` (live device credentials), `pair_count`, `created_at`. A hosted agent also has `bound_device_hash`, `bound_device_name` and `host_name` (the same name), `host_os`, `host_tunnel_name`, `host_online` (the host's tunnel is up) and `host_tunnel_token` (a credential: never print it). There are no `gateway_serving` or `gateway_last_seen` fields: whether an agent is answering is presence, which travels over the mesh, not this API. The persona (motd, photo) is not here either.

### update_agent
Edit an agent's directory entry. **Role:** net-admin.
```
doxx -d "update_agent=1&agent_id=AGENT_ID&owner_only=0"
```
Params: `agent_id` (required). Optional, each independent (omitted fields stay): `agent_name` (rename; every pair sees it), `owner_only` (`1`/`0`), `a2a_enabled` (`1`/`0`), `host_device_hash` (a `device_hash` from `device_list_unified`, or an empty value to unhost). Returns `agent_id`, `changed`, `note` (on a re-host). Re-hosting or unhosting revokes the old host's credentials for this agent at once; the new host claims it on its next check. The host gateway picks changes up within about a minute. `motd` is refused with 410 (it travels over the mesh); a deleted agent answers 410.

### delete_agent
Delete an agent: revokes all its pairs and its device credential, clears its host. **Role:** admin.
```
doxx -d "delete_agent=1&agent_id=AGENT_ID"
```
Returns `deleted_agent_id`, `notes`. The device row and tunnel remain (remove with `delete_tunnel` if the machine is going away); the chat-identity certificate lives on the host and dies with it.

## Bots (group `bots`, deprecated)

Bot accounts are replaced by agent principals. Existing bots keep working until removed; no new bots can be created.

### create_bot
Always answers 410 `create_bot_deprecated` with migration instructions, for every role: use `create_agent` plus the doxxGateway setup. **Role:** any valid token (the answer is the same 410).
```
doxx -d "create_bot=1"
```

### list_bots
List the bots the account owns with seat and liveness state. **Role:** any.
```
doxx -d "list_bots=1"
```
Returns `bots[]`: `bot_user_id`, `bot_name`, `tunnel_count`, `seated` (its tunnel is provisioned), `online` (its tunnel is connected), `created_at`.

### delete_bot
Delete a bot and everything it holds (user row, token, profile, seat grant, pairs, tunnels). **Role:** admin.
```
doxx -d "delete_bot=1&bot_user_id=BOT_USER_ID"
```
Param: `bot_user_id` (from `list_bots`). The seat returns to the plan; the bot's tunnels disconnect. Irreversible.

## Devices (group `devices`)

### device_list_unified
List all devices with seat state, online state and guest accounts. **Role:** any. Works on every plan.
```
doxx -d "device_list_unified=1"
```
Returns an object (the manifest says "array"): `my_devices[]` (`device_hash`, `device_name`, `device_model`, `os_type`, `device_type` (mobile, server, desktop, tablet, or `vps` for a cloud server), `device_icon`, `is_current`, `is_online`, `last_seen`, `last_active_at`, `tunnel_count`, `has_seat`, `can_remove`, `can_rename`, `can_delete`, and optional `services`: per-device service state keyed `remote_desktop`, `mps` or `vps`, each with `state` and `updated_at`), `guest_accounts[]` (`profile_name`, `nickname`, `devices[]`), `subscription` (`exists`, `tier`, `status`, `device_count`, `max_devices`, `is_account_owner`; empty on Free).

### device_rename
Rename a device or change its icon. **Role:** net-admin.
```
doxx -d "device_rename=1&device_hash=DEVICE_HASH&device_name=NEW_NAME"
```
Params: `device_hash`, `device_name` (required); optional `device_icon`. The name cascades to the device's tunnels, seat and share records. Needs no subscription.

### device_delete
Permanently delete another device. **Role:** admin.
```
doxx -d "device_delete=1&target_device_hash=DEVICE_HASH"
```
Param: `target_device_hash`. Cannot delete the device in use (use `device_logout`). Removes its tunnels (disconnected at once), seat, saved profiles and NetDrop share record; its addresses stay on the account. Agents hosted on it are unhosted and their credentials revoked. The device is told to sign itself out; the account's other devices and friends refresh. Returns `deleted`, `tunnels_removed`, `seat_removed`, `netdrop_removed`, `profiles_cleaned`, `ips_freed`, `disconnected`. Irreversible.

### device_status
Read-only check that a device is still registered to the account. **Role:** any.
```
doxx -d "device_status=1&device_id_hash=DEVICE_HASH"
```
Param: `device_id_hash` (the calling device). Returns `registered`, `seated`, `tunnels` (count). No side effects.

### device_service_state
Publish the state of a service hosted on a device (`remote_desktop` or `mps`) so the account's other devices can show it. **Role:** any. **Written by the doxx.net apps on their own device; agents only read it** (the same state appears as `services` on each `device_list_unified` entry).
```
# The call the apps make (agents never send it):
#   doxx -d "device_service_state=1&device_id_hash=DEVICE_HASH&service=mps&state=ready"
# How an agent reads the state:
doxx -d "device_list_unified=1" | jq '.my_devices[] | {device_name, services}'
```
Params: `device_id_hash` (the device), `service` (`remote_desktop` or `mps`), `state` (`off`, `ready`, `blocked`, `busy`, `running`); optional `detail` (a small JSON object with allowlisted keys such as `blocked_reason`, `displays`, `controller_hash`, `since`). Returns `changed`, `rev` and `services` (the device's current service map). A change bumps the device's `rev` and pushes `device_services_updated` to the account's devices. Only the device's own account may write. Do not call it: a wrong state misleads the user's other devices.

### device_logout
Sign the calling device out of the account server side: the `device_delete` cleanup applied to the device named in `device_id_hash`. **Role:** any (the device must belong to the account).
```
doxx -d "device_logout=1&device_id_hash=DEVICE_HASH"
```
Params: `device_id_hash`; optional `tunnel_token` (when sent, it must be one of that device's tunnels, else 403). A cloud server hash (`vps_...`) is refused with 409 `vps_device`, as in `device_delete`: remove a server with `vps_delete`. Idempotent: a device already gone answers `already_absent: true`. Same return fields as `device_delete`, plus `already_absent`. Destructive: use it only to remove the machine the agent itself runs on, with the user's explicit consent. Never pass another device's hash or a `vps_` hash, and never use it as a workaround when `device_delete` is refused (ask for an admin token or use the portal). The device registers as new at its next sign-in.

## DNS blocklists (group `dns_blocklists`)

Per-tunnel blocking. Calls that take a `tunnel_token` need a tunnel that belongs to the account (`list_tunnels`). Changes take effect immediately on active connections.

### dns_get_options
The live catalog of blocklists and allowlists. **Role:** none (no auth).
```
curl -s -X POST https://config.doxx.net/v1/ -d "dns_get_options=1"
```
Returns `options[]`: `name`, `display_name`, `description`, `category` (security, ads, mixed, trackers, content, allowlist), `icon`, `domain_count`, `default_enabled`, `user_toggleable`, `is_base_safety`, `requires_pro`.

### dns_blocklist_stats
The blocklist catalog with counts, for the account. **Role:** any. Read-only: turn a list on or off with `dns_set_subscription`.
```
doxx -d "dns_blocklist_stats=1"
```
Returns `total_domains`, `count`, `lists[]` (`name`, `display_name`, `description`, `category`, `icon`, `domain_count`, `last_download`, `is_base_safety`, `default_enabled`, `user_toggleable`, `enabled`, `requires_pro`). `dns_get_options` has the same catalog without the token.

### dns_get_tunnel_config
A tunnel's blocking configuration. **Role:** any.
```
doxx -d "dns_get_tunnel_config=1&tunnel_token=TUNNEL_TOKEN"
```
Returns `tunnel_token`, `dns_blocking_enabled`, `block_bad_dns_pause_started_at`, `block_bad_dns_pause_until`, `base_protections[]`, `subscriptions[]` (`blocklist_name`, `enabled`: blocklists and allowlists), `whitelists[]` and `blacklists[]` (custom entries with `domain`, `reason`).

### dns_set_subscription
Enable or disable a blocklist or allowlist subscription. **Role:** net-admin.
```
doxx -d "dns_set_subscription=1&tunnel_token=TUNNEL_TOKEN&blocklist_name=NAME&enabled=1"
```
Single mode: `blocklist_name`, `enabled` (0/1). Batch mode: `changes`, a JSON object that maps each blocklist name to `true` or `false`, for example `{"adguard":true,"stevenblack_social":false}` (pass with `--data-urlencode`; an array or a 0/1 value answers 400 "Invalid changes format"). Optional `apply_to_all=1` (every tunnel of the account). Premium lists need Pro.

### dns_add_whitelist
Unblock a domain even if a blocklist covers it. **Role:** net-admin.
```
doxx -d "dns_add_whitelist=1&tunnel_token=TUNNEL_TOKEN&domain=example.com"
```
Params: `tunnel_token`, `domain`; optional `reason`, `apply_to_all=1`.

### dns_remove_whitelist
**Role:** net-admin. Params: `tunnel_token`, `domain`; optional `apply_to_all=1` (remove it from every tunnel of the account). Blocklists may block the domain again.
```
doxx -d "dns_remove_whitelist=1&tunnel_token=TUNNEL_TOKEN&domain=example.com"
```

### dns_add_blacklist
Always block a domain on this tunnel. **Role:** net-admin.
```
doxx -d "dns_add_blacklist=1&tunnel_token=TUNNEL_TOKEN&domain=evil.example"
```
Params: `tunnel_token`, `domain`; optional `reason`, `apply_to_all=1`.

### dns_remove_blacklist
**Role:** net-admin. Params: `tunnel_token`, `domain`; optional `apply_to_all=1` (remove it from every tunnel of the account).
```
doxx -d "dns_remove_blacklist=1&tunnel_token=TUNNEL_TOKEN&domain=evil.example"
```

### dns_blocking_pause
Pause Smart Blocking (`block_bad_dns`) for a while, or clear a pause. **Role:** any.
```
doxx -d "dns_blocking_pause=1&tunnel_token=TUNNEL_TOKEN&seconds=600"
```
Params: `tunnel_token`, `seconds` (0 to 86400; `0` clears a pause). The setting itself does not change: the pause is a self-expiring window, and blocking resumes on its own. Base safety lists keep blocking during a pause. Ignored (current state returned) when Smart Blocking is off; an explicit `update_tunnel` with `block_bad_dns` also ends a pause. Returns `block_bad_dns`, `block_bad_dns_pause_started_at`, `block_bad_dns_pause_until` (unix time, 0 = none), `seconds_remaining`, and the `tunnel_token` (do not print it).

### dns_get_all_tunnel_configs
The DNS configuration of every tunnel in one call. **Role:** any.
```
doxx -d "dns_get_all_tunnel_configs=1"
```
Returns `base_protections[]`, `tunnel_count`, `tunnels[]` (each with `tunnel_token`, `name`, `server`, `dns_blocking_enabled`, `snarf_dns`, `block_doh_dot`, `subscriptions[]`, `whitelists[]`, `blacklists[]`).

### dns_get_user_custom_rules
Every custom blacklist and whitelist entry across all tunnels. **Role:** any.
```
doxx -d "dns_get_user_custom_rules=1"
```
Optional `domain` (substring filter). Returns `blacklists[]` (`tunnel_token`, `tunnel_name`, `domain`, `reason`, `created_at`), `whitelists[]` (same, plus `blocked_by`, `expires_at`), `blacklist_count`, `whitelist_count`.

### dns_get_user_subscriptions
Every blocklist subscription across all tunnels with a per-list summary. **Role:** any.
```
doxx -d "dns_get_user_subscriptions=1"
```
Returns `subscriptions[]` (`tunnel_token`, `tunnel_name`, `blocklist_name`, `enabled`), `summary` (per list: `enabled_count`, `disabled_count`), `tunnel_count`, `subscription_count`.

### public_dns_create_hash
Create a Secure DNS (DoH/DoT) hash that applies a tunnel's blocking config without a tunnel connection. **Role:** net-admin.
```
doxx -d "public_dns_create_hash=1&tunnel_token=TUNNEL_TOKEN&label=phone"
```
Params: `tunnel_token`; optional `label`. Returns `host_hash`, `tunnel_token`, `label`, `doh_url` (`https://<host_hash>.sdns.doxx.net/dns-query`), `dot_host` (`<host_hash>.sdns.doxx.net`). An existing hash for the tunnel is returned as is.

### public_dns_list_hashes
**Role:** any.
```
doxx -d "public_dns_list_hashes=1"
```
Optional `tunnel_token` (only that tunnel's hashes). Returns `count`, `hashes[]` (`host_hash`, `tunnel_token`, `label`, `created_at`, `last_seen_at`, `tunnel_name`, `tunnel_server`).

### public_dns_delete_hash
**Role:** net-admin. Param: `host_hash`. Disables DoH/DoT access for that hash.
```
doxx -d "public_dns_delete_hash=1&host_hash=HASH"
```

## DNS records (group `dns_records`)

Supported types: `A`, `AAAA`, `CNAME`, `MX`, `TXT`, `NS`, `SRV`, `PTR`. The domain must belong to the account. Changes take effect immediately.

### list_dns
**Role:** any.
```
doxx -d "list_dns=1&domain=mysite.doxx"
```
Param: `domain`. Returns `domain` and `records[]` (`name`, `type`, `content`, `ttl`, `prio`; `null` when unset).

### create_dns_record
**Role:** net-admin.
```
doxx -d "create_dns_record=1&domain=mysite.doxx&name=www.mysite.doxx&type=A&content=203.0.113.7&ttl=300"
```
Params: `domain`, `name` (FQDN), `type`, `content` (validated per type: IPv4 for A, IPv6 for AAAA; optional for SRV). Optional: `ttl` (60 to 86400), `prio` (MX/SRV). TTL is per RRset (RFC 2181): omit it to inherit the existing set's TTL; an explicit `ttl` is applied to every record of the same name and type. SRV records use `srv_priority`, `srv_weight`, `srv_port` (1 to 65535) and `srv_target`. CNAME is not allowed at the zone apex. An exact duplicate is idempotent.

### update_dns_record
Replace one record, identified by its old values. **Role:** net-admin.
```
doxx -d "update_dns_record=1&domain=mysite.doxx&old_name=www.mysite.doxx&old_type=A&old_content=203.0.113.7&name=www.mysite.doxx&content=203.0.113.8"
```
Params: `domain`, `old_name`, `old_type`, `old_content`, `name`, and `content` or `srv_target`. Optional `ttl` (kept when omitted), `prio`. The type cannot change: the record keeps `old_type` and a `type` param is ignored (delete and re-create to change it). A change that would duplicate an existing record answers 409.

### delete_dns_record
Delete one record. **Role:** net-admin.
```
doxx -d "delete_dns_record=1&domain=mysite.doxx&name=www.mysite.doxx&type=A&content=203.0.113.7"
```
Params: `domain`, `name`, `type`, `content`. Optional `ttl`, `prio` to pick one of two near-identical records. With duplicates, one record is deleted per call.

### sign_certificate
Sign a PEM CSR with the doxx.net root CA. **Role:** net-admin. **Returns raw PEM (`application/x-pem-file`), not JSON, on success.**
```
printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "sign_certificate=1&domain=mysite.doxx" --data-urlencode "csr@mysite.doxx.csr" --data-urlencode "token@-" -o mysite.doxx.crt
```
Params: `domain` (the account's, under a doxx.net TLD: the root CA is name constrained to the doxx namespace, so imported public domains cannot be signed), `csr` (PEM). The certificate is upgraded to a wildcard (`*.domain` plus `domain`) and is valid 825 days, the longest Apple platforms accept. Every issuance is logged. Create the key and CSR locally (`openssl ecparam -genkey -name prime256v1 -out k.key` then `openssl req -new -key k.key -out d.csr -subj "/CN=mysite.doxx"`); the root CA certificate is downloadable from the portal. On an error the body is JSON: check the first byte before treating the file as a certificate.

## Domains (group `domains`)

### list_tlds
The available doxx.net TLDs. **Role:** none (no auth).
```
curl -s -X POST https://config.doxx.net/v1/ -d "list_tlds=1"
```
Returns `tlds[]` (`tld`, `category`). Optional: `group_by=category` (TLDs grouped per category), `format=count` (per-category counts and `total` only). The number of TLDs is live data: read `total`.

### list_domains
**Role:** any.
```
doxx -d "list_domains=1"
```
Returns `domains[]` (`name`, `id`, `record_count`).

### create_domain
Register a domain under a doxx.net TLD. **Role:** net-admin.
```
doxx -d "create_domain=1&domain=mysite.doxx"
```
Param: `domain` (full name; with no known TLD, `.doxx` is appended). Must not exist, must not be reserved, letters, digits and hyphens, max 253 chars. Creates the SOA and NS records. Rate limited per account. Gate: every account includes a set number of domains; past that, each is an add-on and the call answers 403 `domain_limit` (see Errors). Returns a confirmation and the domain name.

### delete_domain
Delete a domain and all its records (A, AAAA, CNAME, TXT, MX, SRV, PTR, NS, SOA). **Role:** net-admin. Irreversible.
```
doxx -d "delete_domain=1&domain=mysite.doxx"
```

### get_domain_validation
The account's TXT verification code for importing external domains. **Role:** any.
```
doxx -d "get_domain_validation=1"
```
No params; one code per account (generated on first call). Returns `validation_code`. Add it as a TXT record at `_doxx-verify.<domain>` at the DNS provider, then call `import_domain`.

### import_domain
Import an external domain (.com, .net and so on) after TXT verification. **Role:** net-admin.
```
doxx -d "import_domain=1&domain=example.com"
```
Param: `domain` (apex). The handler looks up `_doxx-verify.<domain>` and compares it with the account's stored code: it reads only `domain` (the manifest lists a `validation_code` param, which the server ignores). Refused for doxx.net TLDs (use `create_domain`), for infrastructure domains, and for a domain already registered. Subject to the same `domain_limit` gate as `create_domain`. Returns `nameservers` (`a.root-dx.net`, `a.root-dx.com`, `a.root-dx.org`) to set at the registrar, and a note.

### link_profile_domain
Link a saved profile to a hostname under a domain: creates A and AAAA records that follow the profile's addresses. **Role:** net-admin.
```
doxx -d "link_profile_domain=1&domain=mysite.doxx&hostname=home&profile_id=PROFILE_ID"
```
Params: `domain` (apex, the account's), `hostname` (one label, letters, digits, hyphens), `profile_id`. Returns the FQDN created. The records update when the profile's IPs change.

### unlink_profile_domain
Remove the A/AAAA records created by `link_profile_domain`. **Role:** net-admin. Param: `profile_id`.
```
doxx -d "unlink_profile_domain=1&profile_id=PROFILE_ID"
```

## Firewall (group `firewall`)

Per-tunnel rules, default deny. The firewall is a Pro feature to edit (`firewall_edit`; `purpose=port_forward` checks `port_forwarding`, also Pro), except on a cloud server's own `tunnel_token`: see "Billing, suspension, firewall" under Cloud servers.

### firewall_rule_list
**Role:** any.
```
doxx -d "firewall_rule_list=1"
```
Optional `tunnel_token` (filter). Returns `link_all_enabled`, `rules[]` (`tunnel_token` (do not print), `protocol`, `src_ip`, `src_port`, `dst_ip`, `dst_port`, `enabled`: `false` is a rule that is kept but not enforced), `count`; with a `tunnel_token` also `firewall_enabled`, `ipv6_enabled`. With Full Mesh on, those two flags are in every answer, but they mean something only with a `tunnel_token`: without one they are `false`. With Full Mesh (Link All) off, a call without `tunnel_token` lists every rule of the account. With Full Mesh on, rules come only per tunnel: **without `tunnel_token` the answer is `rules: null`, `count: 0`**, so call it once per tunnel; each call lists only that tunnel's enforced rules (the parked tunnel-to-tunnel rules are not shown), plus `user_tunnel_ips`. `rules` is JSON `null`, not `[]`, whenever there are none, in both modes: read it as `.rules // []`.

### firewall_rule_add
**Role:** net-admin.
```
doxx -d "firewall_rule_add=1&tunnel_token=TUNNEL_TOKEN&protocol=TCP&src_ip=0.0.0.0/0&src_port=ALL&dst_ip=TUNNEL_IP&dst_port=443"
```
Params: `tunnel_token`, `src_ip` (address or CIDR), `dst_ip` (must be one of the account's addresses); optional `protocol` (`TCP`, `UDP`, `ICMP`, `ALL`; default `ALL`), `src_port`, `dst_port` (a port 1 to 65535, a range `8000-8100`, or `ALL`; default `ALL`), `purpose=port_forward` (so a plan refusal names Port Forwarding). Cannot create tunnel-to-tunnel links while Link All is on. The plan's rule quota answers 409 "Firewall rule limit reached"; an identical rule answers 409 "already exists". On a cloud server's own `tunnel_token` there is no plan gate and no device quota: the per-server cap answers 409 `vps_firewall_limit` (`used`, `max`, `fix`, `upgrade_url` as a portal path). Caution with `src_ip` pinned to one public address: ISPs rotate addresses and a device on a doxx.net tunnel arrives from its tunnel IP, so a stale pin drops packets silently; prefer protocol and port scoping.

### firewall_rule_delete
Delete a rule, matched on all of its fields. **Role:** net-admin.
```
doxx -d "firewall_rule_delete=1&tunnel_token=TUNNEL_TOKEN&protocol=TCP&src_ip=0.0.0.0/0&src_port=ALL&dst_ip=TUNNEL_IP&dst_port=443"
```
All six params are required, with no defaults: `tunnel_token`, `protocol`, `src_ip`, `src_port`, `dst_ip`, `dst_port`. Copy them from the rule as `firewall_rule_list` shows it, and send `ALL` explicitly where the rule has `ALL` (a rule added without a protocol or ports has `ALL` there). A missing param answers 400; a value that matches no rule answers 404 "Firewall rule not found". 423 under a settings lock.

### firewall_link_all_status
Is Full Mesh (Link All) on. **Role:** any.
```
doxx -d "firewall_link_all_status=1"
```
Returns `link_all_tunnels` (0 or 1).

### firewall_link_all_toggle
Turn Full Mesh on or off: all of the account's tunnels may talk to each other, across servers, over the encrypted backbone. **Role:** net-admin.
```
doxx -d "firewall_link_all_toggle=1&enabled=1"
```
Param: `enabled` (0/1). When enabled, existing tunnel-to-tunnel rules go dormant (kept, not enforced) and return when disabled; inbound rules from outside the account are untouched. Returns `link_all_tunnels`, `rules_dormant`, `rules_restored`.

## IP addresses (group `ip_addresses`)

Address types: `static_private`, `static_public`, `static_ipv6`. Addresses live on saved profiles, at one site each.

### list_addresses
**Role:** any.
```
doxx -d "list_addresses=1"
```
Optional `tunnel_token`, `device_hash` (filters). Returns `addresses[]` (`address`, `type`, `site_id`, `location`, `profile_id`, `profile_name`, `tunnel_name`, `connected`, `device_name`, `persistent`), `public_ipv4_used`, `public_ipv4_max`.

### assign_address
Move an address onto a saved profile. **Role:** net-admin.
```
doxx -d "assign_address=1&address=ADDRESS&type=static_public&profile_id=PROFILE_ID"
```
Params: `address`, `type`, `profile_id` (`0` or empty unassigns). An IP lock on the profile does not block it. Optional `update_location=1` (on a site mismatch, move the profile's server to the address's site), `tunnel_token` (the caller's own tunnel, so the answer says whether this device must reconnect). One IPv4 per profile: a public IPv4 releases the private one and the other way round. Returns `replacement_ip` (an unassign left the profile a fresh private address), `needs_reconnect`, `reconnect_this_device`, `reconnect_device`, `reconnect_message`. Site mismatch: 409 with key `error: "site_mismatch"`, `ip_location`, `ip_site_id`, `profile_location`, `profile_site_id`, `profile_name`.

### release_address
**Role:** net-admin.
```
doxx -d "release_address=1&address=ADDRESS&type=static_public"
```
Params: `address`, `type`; optional `tunnel_token`. Returns `replacement_ip` (the profile lost its only address and got a private one), `needs_reconnect`, `reconnect_message`. 423 when the profile has an IP lock. The address is deleted from the account: with `type=static_public` the dedicated IPv4 is gone for good and may never come back (irreversible; confirm first).

### rotate_address
New random address at the same site; the old one is gone. **Role:** net-admin.
```
doxx -d "rotate_address=1&address=ADDRESS&type=static_private"
```
Params: `address`, `type` (`static_private` or `static_ipv6` only: a public IPv4 cannot be rotated). Returns `new_address`. 423 under an IP lock.

### lease_public_ipv4
Lease a dedicated public IPv4. **Role:** net-admin.
```
doxx -d "lease_public_ipv4=1&profile_id=PROFILE_ID"
```
Three modes: (1) `profile_id`; (2) `profile_name` plus `server` (creates a profile); (3) `server` alone (pool-only lease). Modes 1 and 2 always lease an IPv6 for the profile too (unless it already has one), whatever `include_ipv6` says. Optional: `include_ipv6=1` (pool-only mode), `ip_type=ipv6` (IPv6 only, honoured only in pool-only mode), `profile_icon`, `profile_type`, `tunnel_token` (in-use detection). Returns `ip_address`, `ipv6_address`, `site_id`, `server`, `profile_id`, `message`, flags `pool_only`, `profile_created`, `requires_reconnect`. Gates: an IPv4 needs a dedicated IP slot (an add-on; without one `feature_required` with `feature: "dedicated_ip"`; all used: 409 "All dedicated IP slots in use"); an IPv6 lease needs the `internet` feature; a profile that already has a public IPv4 or an IP lock (423) is refused; mode 1 fails with 400 when the profile has no preferred server.

### list_ip_reservations
**Role:** any.
```
doxx -d "list_ip_reservations=1"
```
Returns `reservations[]` (`ip_address`, `server`, `profile_id`, `profile_name`), `slots_used`, `slots_max`.

### release_ip_reservation
Unlink a dedicated IPv4 from its saved profile. **Role:** net-admin. Param: `ip_address`.
```
doxx -d "release_ip_reservation=1&ip_address=ADDRESS"
```
The address stays on the account as a pool-only address (no profile) and still uses a dedicated IP slot; the profile's `ipv4_public_enabled` is turned off. 400 when the address is not on a profile. To give the address up for good, use `release_address` with `type=static_public` (irreversible).

## Proxy (group `proxy`)

Web Privacy: web traffic appears from another location with a spoofed browser fingerprint. Enabling it needs the `proxy` feature (Pro).

### get_proxy_config
**Role:** any.
```
doxx -d "get_proxy_config=1&tunnel_token=TUNNEL_TOKEN"
```
Returns `config`: `tunnel_token`, `assigned_ip`, `assigned_v6`, `enabled` (boolean), `location` (default `newyork-us`), `browser`, `custom_lat`, `custom_lon`, `custom_timezone`, `custom_language`.

### update_proxy_config
**Role:** net-admin.
```
doxx -d "update_proxy_config=1&tunnel_token=TUNNEL_TOKEN&enabled=1&location=newyork-us"
```
Params: `tunnel_token`; `enabled` (`1`/`0`), `location`, `browser`, `hardware`. The manifest lists `cloud_proxy_*` names: the handler reads the four above. It is a full write of the row: an omitted `enabled` counts as 0 (disables the proxy), an omitted `location` resets to `newyork-us`, and omitted `browser` and `hardware` become empty. Send the current values of everything you do not change (from `get_proxy_config`). Mobile tunnels get the app proxy, other tunnels the cloud proxy; the two exclude each other. 423 when the tunnel's saved profile has a settings lock.

## Saved profiles (group `saved_profiles`)

A profile is a named snapshot of tunnel settings plus reserved addresses. Types do not mix: `wireguard` profiles are for standalone WireGuard clients (created in the portal or with `create_saved_profile`); `ios` or `android` profiles are for app-managed connections.

### list_saved_profiles
**Role:** any.
```
doxx -d "list_saved_profiles=1"
```
Returns `profiles[]`: `profile_id`, `profile_name`, `profile_icon`, `profile_notes`, `profile_type`, `preferred_server`, `domain_name`, the settings flags (`block_bad_dns`, `firewall`, `kill_switch`, `transport` and the rest), `locked`, `ip_locked`, `settings_locked`, `source_tunnel_name`, `created_at`, `updated_at`, and `in_use`, `in_use_by`, `in_use_device_icon`, `in_use_tunnel_token` (a credential: never print it). `in_use: false` does not mean no tunnel is bound.

### create_saved_profile
Create an empty profile (for static addresses with standalone WireGuard clients). **Role:** net-admin.
```
doxx -d "create_saved_profile=1&profile_name=NAME&server=SERVER_HOSTNAME"
```
Params: `profile_name` (max 128 chars), `server`; optional `profile_icon`, `profile_type` (default `wireguard`). For app profiles use `save_profile`. Returns `profile_id`. Gates: `feature_required` with `feature: "saved_profiles"` (Pro); the plan's profile quota answers 409 "Profile limit reached".

### save_profile
Snapshot a tunnel's settings (DNS blocklists, firewall, proxy, transport, server) into a new profile. **Role:** net-admin.
```
doxx -d "save_profile=1&tunnel_token=TUNNEL_TOKEN&profile_name=NAME"
```
Params: `tunnel_token`, `profile_name` (max 128 chars); optional `profile_icon`, `profile_notes`, `profile_type`, `preferred_server`, `save_preferred_server=1`, `lock_after_save=1`. Returns `profile_id` and `bound` (the source tunnel now uses the profile: it had none, was not in Easy Mode, and the profile is for its own location). Gates: `feature_required` with `feature: "saved_profiles"` (Pro); the plan's profile quota answers 409 "Profile limit reached".

### update_saved_profile
Update a profile's metadata. **Role:** net-admin.
```
doxx -d "update_saved_profile=1&profile_id=PROFILE_ID&profile_name=NEW_NAME"
```
Params: `profile_id`; optional `profile_name`, `profile_icon`, `profile_notes`. The preferred server is not changed here. **Do not send `re_snapshot=1`:** it deletes the profile and still answers "Profile re-snapshotted". To capture a tunnel's current settings, use `save_profile` to a new profile.

### load_profile
Apply a profile to a tunnel. **Role:** net-admin. **Replaces all the tunnel's settings** with the profile's snapshot.
```
doxx -d "load_profile=1&tunnel_token=TUNNEL_TOKEN&profile_id=PROFILE_ID"
```
Params: `tunnel_token`, `profile_id`; optional `source` (the tunnel's type: `ios`, `android` or `wireguard`), `lock_after_load=1` (`switch_server` is accepted but ignored). The profile type is checked only when `source` is sent (400 "Cannot apply a ... profile to a ... tunnel"): without it a mismatched profile loads anyway, so check `profile_type` yourself first, and its location must match the tunnel's (400 "Profile location does not match tunnel location"); refused when the profile is in use on another device (conflict). Pro settings inside the profile need their own Pro features. Returns `profile_id`, `profile_name`, `mode`.

### delete_saved_profile
**Role:** net-admin. Param: `profile_id`. Permanent. Tunnels on it are detached; its addresses stay on the account without a profile; a tunnel on its dedicated IPv4 gets a new private address (the response then has `needs_reconnect`).
```
doxx -d "delete_saved_profile=1&profile_id=PROFILE_ID"
```

### lock_profile
Lock a profile against IP and/or settings changes. **Role:** net-admin.
```
doxx -d "lock_profile=1&profile_id=PROFILE_ID&lock_type=ip"
```
Params: `profile_id` or `tunnel_token`; optional `lock_type` (`ip`, `settings`; omit for both). Returns `profile_id`, `lock_type`. A lock makes the affected calls answer 423 (see Errors). An IP lock blocks `release_address`, `rotate_address` and `lease_public_ipv4` on the profile, not `assign_address`. A settings lock blocks `update_tunnel`, `update_proxy_config`, the DNS subscription and custom rule writes, and `firewall_rule_add` / `firewall_rule_delete`, not `set_mobile_options`.

### unlock_profile
**Role:** net-admin. Params: `profile_id` or `tunnel_token`; optional `lock_type`.
```
doxx -d "unlock_profile=1&profile_id=PROFILE_ID"
```

### apply_mode
Apply a connection mode template to a tunnel. **Role:** net-admin. **A REPLACE, not a patch.**
```
doxx -d "apply_mode=1&tunnel_token=TUNNEL_TOKEN&template_key=security" --data-urlencode 'settings={"block_bad_dns":1,"kill_switch":1}'
```
Params: `tunnel_token`, `settings` (JSON object; only these keys: `auto_reconnect`, `bandwidth_stats`, `block_bad_dns`, `block_doh_dot`, `connect_on_startup`, `connection_profile`, `enable_routing`, `firewall`, `ipv4_public_enabled`, `ipv6_enabled`, `keep_established_ssh`, `kill_default_route`, `kill_switch`, `mtu_spoofing`, `onion_enabled`, `port`, `proxy_enabled`, `security_stats`, `snarf_dns`, `transport`; unknown keys are a 400), optional `template_key` (`default` resets to a freshly created tunnel's settings and blocklists), `dns` (JSON). Every omitted key resets to its default; DNS blocklists, whitelists and blacklists are replaced; the tunnel detaches from its saved profile and releases profile-reserved IPs (a dedicated public IPv4 too), and assigned tunnel IPs are cleared so the next connect allocates fresh ones. The device must reconnect. Needs the `modes` feature (not on Free). To change one setting use `update_tunnel`. Returns `template_key`, `mode`.

## Servers and info (group `servers_and_info`)

### servers
Tunnel locations. **Role:** none (no auth). Cached 5 minutes.
```
curl -s -X POST https://config.doxx.net/v1/ -d "servers=1"
```
Optional `type` (filter, for example `wireguard`). Returns `servers[]`: `server_name`, `hostname` (the same value: pass it as `server` to tunnel and profile calls), `location`, `description`, `type`, `operator`, `continent`, `flag_image`, `bg_image`, `best_for`, `cluster_key_count`, `public_key` (always empty: each tunnel gets its own server key). Each location is a cluster addressed by one hostname: choose the nearest.

### network_info
What the caller's network looks like from doxx.net's side. **Role:** any.
```
doxx -d "network_info=1"
```
Returns `ip` (the public address the request came from), `family` (`ipv4`/`ipv6`), `asn` and `org` (the ISP; left out for a private or unrouted address), `node`, `ts`, `history` (always `none`). Answered from a local database: no outside service is asked and nothing is recorded. Call it once when the network changes, never on a timer: 30 calls a minute per account (then 429). When internet traffic runs through a doxx.net tunnel, `org` usually shows doxx.net.

## Tokens (group `tokens`)

Roles: `admin`, `net-admin`, `read-only`, and `device` (a gateway credential bound to one tunnel). Every call here needs `admin` except `user_list_tokens` (any role), and `create_token` with `role=device` (a `net-admin` token may mint it). `target_token` is the full token string: read it from `user_list_tokens` inside the shell and never print it (a `device` credential is not in that list).

### user_list_tokens
**Role:** any. An admin token sees every token on the account; a `net-admin` or `read-only` token sees only itself. Gateway (`device`) credentials are never listed, for any caller: a `device` token gets an empty list, not itself. Manage those through the agent: `list_agents` (`credentials`, the live count), `update_agent` (re-hosting or unhosting revokes them) and `delete_agent`.
```
doxx -d "user_list_tokens=1" | jq '.tokens // [] | .[] | {label, role, expires_at, revoked_at, is_current}'
```
Returns `tokens[]`: `token` (full value: filter it out), `label`, `role`, `created_at`, `expires_at`, `revoked_at`, `is_current`, `geo_fence[]` (`country`, `label`), `ip_fence[]` (`cidr`, `label`), `tunnel_scope[]` (`tunnel_token`, `label`). `tokens` is `null` when the list is empty.

### create_token
**Role:** admin (`net-admin` for `role=device`). The full token string is returned once.
```
doxx -d "create_token=1&label=my-agent&role=net-admin&expires_at=2026-12-17T00:00:00Z"
```
Optional: `label` (max 64 chars), `role` (`admin`, `net-admin`, `read-only`, `device`; **default `read-only`**), `expires_at` (RFC3339). Always pass `role` and `expires_at` explicitly. `role=device` needs `tunnel_token` (one of the account's tunnels; the token is born bound to it) and takes an optional `agent_id` (binds that agent to the tunnel's device; the tunnel needs a device hash). Returns `new_token` (store it securely, never print it); for `device` also `role`, `bound_tunnel` (a `tunnel_token`) and `bound_agent_id`.

### update_token
Change label, role or expiry. **Role:** admin.
```
doxx -d "update_token=1&target_token=TARGET_TOKEN&expires_at=2027-01-01T00:00:00Z"
```
Params: `target_token`; optional `label` (empty clears it), `role` (`admin`, `net-admin`, `read-only`), `expires_at` (RFC3339 or `never`). Works on an expired token (extend its expiry to revive it), not on a revoked one. Cannot lower the role of your own active token.

### revoke_token
Revoke at once (soft). **Role:** admin. Param: `target_token`. The token stays listed with `revoked_at`. Refused for your own active token and the last admin token.
```
doxx -d "revoke_token=1&target_token=TARGET_TOKEN"
```

### unrevoke_token
Re-enable a revoked token with its role, fences and tunnel scope intact. **Role:** admin. Param: `target_token`. Errors when the token is not revoked.
```
doxx -d "unrevoke_token=1&target_token=TARGET_TOKEN"
```

### delete_token
Delete a token and its fences and scope for good. **Role:** admin. Param: `target_token`. Same refusals as `revoke_token`. Prefer revoke unless the user wants the token gone.
```
doxx -d "delete_token=1&target_token=TARGET_TOKEN"
```

### add_geo_fence
Allow a token only from listed countries (GeoIP; a failed lookup is allowed). **Role:** admin.
```
doxx -d "add_geo_fence=1&target_token=TARGET_TOKEN&country=US"
```
Params: `target_token`, `country` (ISO 3166-1 alpha-2); optional `label`.

### remove_geo_fence
**Role:** admin. Params: `target_token`, `country`. Removing the last entry removes the restriction.
```
doxx -d "remove_geo_fence=1&target_token=TARGET_TOKEN&country=US"
```

### add_ip_fence
Allow a token only from listed addresses. **Role:** admin.
```
doxx -d "add_ip_fence=1&target_token=TARGET_TOKEN&cidr=203.0.113.0/24"
```
Params: `target_token`, `cidr` (IPv4/IPv6 address or CIDR; a bare address becomes /32 or /128; a CIDR is normalized to its network address); optional `label`.

### remove_ip_fence
**Role:** admin. Params: `target_token`, `cidr` (exactly as stored). Removing the last entry removes the restriction.
```
doxx -d "remove_ip_fence=1&target_token=TARGET_TOKEN&cidr=203.0.113.0/24"
```

### add_token_tunnel
Restrict a token to a tunnel: with any scope entry it sees and changes only those tunnels. **Role:** admin.
```
doxx -d "add_token_tunnel=1&target_token=TARGET_TOKEN&tunnel_token=TUNNEL_TOKEN"
```
Params: `target_token`, `tunnel_token` (the account's); optional `label`.

### remove_token_tunnel
**Role:** admin. Params: `target_token`, `tunnel_token`. Removing the last entry gives the token every tunnel again.
```
doxx -d "remove_token_tunnel=1&target_token=TARGET_TOKEN&tunnel_token=TUNNEL_TOKEN"
```

Recovery codes are created and redeemed in the portal, not through the API. Redeeming one makes doxx.net assume the account is compromised: every token on the account is revoked, gateway (`device`) credentials included, and one new `admin` token (label `Primary`) goes to whoever redeemed it. The revoked `device` credentials do not appear in `user_list_tokens`, so they cannot be re-enabled from there: re-run each gateway's setup (`list_agents` shows `credentials: 0` until then).

## Tunnels (group `tunnels`)

### list_tunnels
**Role:** any. Every tunnel's `private_key` and `tunnel_token` are in the answer: always filter with `jq`.
```
doxx -d "list_tunnels=1" | jq '.tunnels[] | {name, server, assigned_ip, is_connected, connection_status}'
```
Optional: `device_hash`, `device_type` (filters), `include_vps=1` (also return cloud server tunnel rows, hidden by default). Returns `tunnels[]` with `tunnel_token`, `name`, `server`, `assigned_ip`, `assigned_v6`, `public_ipv4` (when a dedicated IPv4 is bound), `public_key`, `private_key`, `is_connected`, `connection_status`, the settings flags (`firewall`, `ipv6_enabled`, `block_bad_dns`, `ip_options_filter` and the rest), `mode`, `active_profile_id`, `active_profile_name`, and the top-level `mesh_public_pools` (CIDRs of the dedicated public IPv4 pools: a source address inside one is a doxx.net device, not a stranger). Fields that are not update params are read-only status.

### create_tunnel
Create a generic WireGuard tunnel (desktop, server, WireGuard app). **Role:** net-admin.
```
doxx -d "create_tunnel=1&type=wireguard&server=SERVER_HOSTNAME&name=NAME"
```
Params: `server` (hostname from `servers`), `type` (`wireguard`, `tcp-encrypted`, `https` or `cdn`; use `wireguard`, and always pass it: the handler refuses a call without it, though the manifest says it defaults to `wireguard`). Optional: `name` (max 64 chars), `profile_id`, and initial flags, each 0/1: `bandwidth_stats`, `security_stats`, `block_bad_dns`, `block_doh_dot`, `keep_established_ssh`, `kill_default_route`, `auto_reconnect`, `enable_routing`, `snarf_dns`, `firewall`, `ipv6_enabled`, `mtu_spoofing`, `ip_options_filter`. Returns only `message` and `tunnel_token` (the manifest promises the whole WireGuard config: fetch it with `wireguard`). Gates: needs the `connect` feature (a paused, expired or revoked account is refused: `feature_required`); `seat_limit` for a new device when all seats are used. Edge servers are notified to apply the tunnel.

### create_tunnel_mobile
The apps' alias of `create_tunnel`: the same handler in mobile mode. **Role:** net-admin. Do not use it for generic WireGuard clients.
```
doxx -d "create_tunnel_mobile=1&device_hash=DEVICE_HASH&server=SERVER_HOSTNAME"
```
Params as `create_tunnel`, but `device_hash` is required and `type` defaults to `wireguard`. Optional `mode`, `mode_settings` (JSON), `mode_dns` (JSON) apply a connection mode on first connect. Returns the full config including `private_key`, `public_key`, `assigned_ip`, `assigned_v6`, `config`, `wireguard_config`, and `public_ipv4` when one is allocated: never print it.

### create_native_tunnel
Create or refresh the tunnel of a doxx.net native iOS, Android or macOS app install. **Role:** net-admin.
```
doxx -d "create_native_tunnel=1&device_hash=DEVICE_HASH&server=SERVER_HOSTNAME"
```
Params: `device_hash` (from `device_list_unified` or `list_tunnels`), `server`; optional `name`, `profile_id`. Checks the `connect` feature, then runs the mobile path of `create_tunnel`, so the answer and the gates (`seat_limit`) are the same as `create_tunnel_mobile`. It reuses the device's existing tunnel; moving it to another server without `profile_id` detaches its saved profile. Do not call `wireguard` on a native tunnel. This is the call that gives a gateway agent its device tunnel.

### update_tunnel
PATCH a tunnel: only the fields passed change. **Role:** net-admin.
```
doxx -d "update_tunnel=1&tunnel_token=TUNNEL_TOKEN&name=NEW_NAME&block_bad_dns=1"
```
Params: `tunnel_token`; any of `name` (max 64), `server`, `mode` (empty string clears it), `type` (`wireguard`, `tcp-encrypted`, `https`, `cdn`), and the 0/1 flags `bandwidth_stats`, `security_stats`, `block_bad_dns`, `block_doh_dot`, `keep_established_ssh`, `kill_default_route`, `auto_reconnect`, `enable_routing`, `snarf_dns`, `firewall`, `ipv6_enabled`, `onion_enabled`, `mtu_spoofing`, `ip_options_filter` (default 1: the server drops inbound connection attempts with risky IPv4 options or IPv6 extension headers and strips MPTCP negotiation toward this tunnel; set 0 only when MPTCP or source-routed diagnostics run behind a port forward). If a saved profile is active, flag changes also go to the profile. 423 when the profile has a settings lock. Turning `firewall` off deletes the tunnel's rules. Edge servers are notified.

### delete_tunnel
**Role:** net-admin. Param: `tunnel_token`. Frees the addresses; active connections drop at once. Irreversible.
```
doxx -d "delete_tunnel=1&tunnel_token=TUNNEL_TOKEN"
```

### wireguard
The WireGuard configuration of a generic tunnel. **Role:** any (a `device` credential for its own tunnel). **The answer holds the tunnel private key**: build the config file in a private temp directory with `jq`, as in the skills' WireGuard recipe; never print it.
```
doxx -d "wireguard=1" --data-urlencode "tunnel_token=TUNNEL_TOKEN" | jq '{status, requires_reconnect}'
```
Param: `tunnel_token`. Returns `config` with `interface` (`private_key`, `address`, `dns`) and `peer` (`public_key`, `allowed_ips`, `endpoint`, `persistent_keepalive`). Generic WireGuard tunnels only: never call it on a native app tunnel.

### get_mobile_options
**Role:** any.
```
doxx -d "get_mobile_options=1&tunnel_token=TUNNEL_TOKEN"
```
Returns `mobile_options`: `connect_on_startup`, `kill_switch`, `transport`, `port` (`null` for the default), `proxy_enabled`, `onion_enabled`, `connection_profile`, `tcp_fingerprint`, `netdrop_turbo` (0/1: NetDrop transfer profile, 1 turbo, 0 polite).

### set_mobile_options
Change connection and transport options. **Role:** net-admin. A PATCH: only the params passed change.
```
doxx -d "set_mobile_options=1&tunnel_token=TUNNEL_TOKEN&kill_switch=1&connect_on_startup=1"
```
Params: `tunnel_token`; any of `kill_switch`, `connect_on_startup`, `proxy_enabled`, `onion_enabled`, `netdrop_turbo`, `firewall` (0/1), `transport`, `port` (1 to 65535), `connection_profile`, `tcp_fingerprint`, `ipv4_public_enabled` (0/1). Per code the values are: `transport` `normal`, `wss`, `sip`, `icmp`, `quic`, `cloudflare`, `https` (anything but `normal` is Covert Communications, a Pro feature: `feature_required`); `connection_profile` `security`, `tinfoilhat`, `streaming`, `censorship`, `custom` (it becomes `custom` on its own when you change a setting without passing one); `tcp_fingerprint` `auto`, `ios`, `macos`, `windows`, `linux`, `android`, `freebsd`, `openbsd`, `solaris`, `zos`, `os2warp`, `random`. The manifest lists `stealth`/`obfuscated` and `speed`: the handler rejects them. `ipv4_public_enabled=1` can answer `dedicated_ip_limit` (see Errors); `=0` detaches the profile and swaps to a private IPv4. There is no settings-lock check here (no 423). Fields it does not know are skipped without an error ("No changes to save"): read the options back after a write.


## Cloud servers (group `vps`)

A cloud server is a KVM virtual machine in a doxx.net data centre with its own public IPv4 (/32) and IPv6 (/64), on the account's mesh, with a host-side firewall. Creating one needs the entitlements feature `vps` (the VPS add-on, sold on every plan with no Pro requirement, or an admin grant) and room in `limits.vps`, `vps_ram_gib`, `vps_vcpu`, `vps_disk_10gb` (the last three count each server's extras above the base shape). `vps_catalog`, `vps_list`, `vps_get` and `vps_rdns` `get` accept any token role; all other calls need **net-admin**. `vps_create`, `vps_list` and `vps_get` answers contain the server's `tunnel_token`: a credential, filter it out before display.

### vps_catalog
**Role:** any. Regions, images and pricing. Read prices from here at runtime; do not hardcode them.
```
doxx -d "vps_catalog=1"
```
Returns: `regions[]` (`id`, `name`, `available`), `images[]` (`id`, `name`, `arch`, `sha256`, `default`), `pricing` (`base` with `vcpus`, `memory_gib`, `disk_gb`, `monthly_usd`, `includes`; `increments` with `memory_gib`, `vcpu`, `disk_10gb` monthly prices; `caps` with `vcpus`, `memory_gib`, `disk_gb`, `disk_step_gb`; `presets[]` with `id` (`s`, `m`, `l`), `label`, `vcpus`, `memory_gib`, `disk_gb`, `monthly_usd`, `annual_usd`; `annual_multiplier`; `currency`; `requires_pro` (false: any plan); `firewall_rules_per_server` (per-server firewall rule cap by plan id: `free`, `basic`, `pro`, `proplus`)).

### vps_create
**Role:** net-admin.
```
doxx -d "vps_create=1&name=web1&size=s&site=mia1" --data-urlencode "ssh_keys@$HOME/.ssh/id_ed25519.pub"
```
Required: `name` (DNS label: lowercase letters, digits, hyphens, 1 to 63 characters, unique among the account's servers), `ssh_keys` (OpenSSH public key lines, JSON array or newline-separated; password SSH is off). Shape: `size` (`s`, `m`, `l`) and/or `vcpus`, `memory_gib`, `disk_gb` (explicit values override the preset; default is the base shape). Optional: `site` (alias `region`, default `mia1`), `image` (default Debian 13), `domain` (one of `list_domains`: names the server `<name>.<domain>`). Order of checks: role, feature `vps`, shape, `vps_limit`, name, image, domain, keys, duplicate name, host capacity.
Returns: `vps_id`, `device_hash` (`vps_<id>`), `tunnel_token`, `name`, `state` (`pending`), `rev`, `region`, `host`, `public_ipv4`, `public_ipv6`, `public_ipv6_prefix`, `shape`, `monthly_usd`, `image`, `mesh_mode` (`mine`), `mesh_open`, `domain`, `fqdn`, `message`. Side effects: a device row (no seat), a virtual tunnel row of type `vps`, and two ICMP-only internet firewall rules (IPv4 and IPv6). Poll `vps_get` until `state` is `running` (about a minute).
Errors: 409 `vps_limit` (`component` servers/memory/cores/storage, `available`, `needed`, `monthly_usd`, `fix`, `upgrade_url` as a portal path), 409 duplicate name, 409 no capacity in the region, 503 hosts unreachable or address allocation failed, 403 domain not yours, 400 bad name/shape/image/keys.

### vps_list
**Role:** any.
```
doxx -d "vps_list=1"
```
Returns: `count`, `servers[]` (`vps_id`, `device_hash`, `tunnel_token`, `name`, `domain`, `fqdn`, `region`, `region_name`, `host`, `public_ipv4`, `public_ipv6`, `public_ipv6_prefix`, `size`, `vcpus`, `memory_mb`, `disk_gb`, `image`, `state`, `detail`, `progress`, `rev`, `applied_rev`, `firewall_applied_at`, `created_at`, `started_at`, `rdns_v4`, `rdns_v6`, `ssh_command` (`ssh root@<public_ipv4>`), `monthly_usd`, `firewall_enabled`, `firewall_rules_used`, `firewall_rules_max` (`-1`: no cap), `mesh_mode`, `mesh_open`, `password_applied`, `keys_applied`, `bw_month_gb`, `bw_month_mb`, `bw_mesh_month_gb`, `throttled`, `egress_cap_mbps`), `bandwidth_pool`. States: `pending`, `provisioning`, `starting`, `booting`, `running`, `stopping`, `stopped`, `restarting`, `suspended`, `destroying`, `error`.

### vps_get
One server by `vps_id`, the same object `vps_list` returns per server. **Role:** any.
```
doxx -d "vps_get=1&vps_id=VPS_ID"
```
Returns: `vps` (one `servers[]` entry with `bandwidth_pool` nested inside it, at `.vps.bandwidth_pool`; `vps_list` has it at the top level). 404 if not found. Poll it after `vps_create` until `state` is `running`, and after `vps_keys` or `vps_root_password` until `keys_applied` or `password_applied` turns true.

### vps_power
**Role:** net-admin.
```
doxx -d "vps_power=1&vps_id=VPS_ID&action=restart"
```
`action`: `start`, `stop` (clean shutdown, forced by the host if it does not finish), `restart`. Returns: `vps_id`, `state` (`starting`, `stopping`, `restarting`). 409 while the server is `pending`, `provisioning`, `destroying` or `suspended`.

### vps_mesh
**Role:** net-admin.
```
doxx -d "vps_mesh=1&vps_id=VPS_ID&mode=mine"
```
`mode`: `mine` (default at create: every connection from the account's own tunnels, seated guests, dedicated addresses and other servers), `full` (every doxx.net tunnel, dedicated address pool and cloud server pool), `off` (only firewall rules apply). Legacy `enabled=1` means `full`, `enabled=0` means `off`. Applied on the host ahead of the firewall rules; the internet always sees only the rules. Returns: `mesh_mode`, `mesh_open`, `mesh_prefixes` (`ipv4`, `ipv6`), `note`. Reaches the host within a minute.

### vps_dns
**Role:** net-admin.
```
doxx -d "vps_dns=1&vps_id=VPS_ID&domain=example.com"
```
Writes A and AAAA for `<name>.<domain>` and matching PTRs; a new domain moves them; `domain=` (empty) removes them. Returns: `vps_id`, `domain`, `fqdn`, `records` (`A`, `AAAA`, `PTR`). 403 if the domain is not the account's.

### vps_rdns
**Role:** any for `get`, net-admin for `set` and `clear`.
```
doxx -d "vps_rdns=1&vps_id=VPS_ID&sub_action=set&family=v4&name=mail.example.com"
```
`sub_action`: `get` (default, any role: returns `v4` and `v6`, each `address` and `ptr`, plus `note`), `set` (net-admin: `family` `v4`/`v6`, default `v4`, and `name` = a fully qualified host name), `clear` (net-admin: `family`). PTRs are removed when the server is deleted.

### vps_root_password
**Role:** net-admin.
```
doxx -d "vps_root_password=1&vps_id=VPS_ID&sub_action=get"
```
`sub_action`: `get` (default) or `reset`. Returns: `vps_id`, `user` (`root`), `password`, `applied` (`reset` also `note`). The password is for the console and recovery; SSH is key-only. After a reset the host applies it within a minute (`password_applied` on `vps_get`). `get` answers 404 for servers created before Nov 9 2026 (no password on file): reset to set one. Each call is audited. Agents: write the password to a 0600 file, never into the conversation.

### vps_keys
**Role:** net-admin.
```
doxx -d "vps_keys=1&vps_id=VPS_ID&sub_action=set" --data-urlencode "keys@$HOME/.ssh/id_ed25519.pub"
```
Replaces root's authorized keys (`keys`: same format as `ssh_keys`). The list is not stored by doxx.net; there is no `list`. Returns: `vps_id`, `user`, `count`, `applied` (false), `note`. `keys_applied` on `vps_get` turns true once the host writes them; a stopped server gets them when it starts.

### vps_delete
**Role:** net-admin.
```
doxx -d "vps_delete=1&vps_id=VPS_ID&confirm=web1"
```
`confirm` must equal the server's name exactly (400 otherwise). Irreversible: the host removes the VM and disk; firewall rules, DNS records, PTRs and the device row go; the addresses return to the pool after a 30 day quarantine; the add-on capacity frees when the host finishes. Returns: `vps_id`, `state` (`destroying`), `message`. 409 if already being deleted.

### Billing, suspension, firewall
- When the plan lapses or the VPS add-on drops below what the servers use, the newest servers are suspended (stopped) until the rest fit; a suspended server is destroyed after a 14 day grace period, and resumes if the account pays again in time. The deadline is in `device_list_unified` `my_devices[].services.vps.detail.expires_at`.
- Internet ports are opened with `firewall_rule_add` / `firewall_rule_delete` / `firewall_rule_list` on the server's `tunnel_token`, with `public_ipv4` or `public_ipv6` as `dst_ip`. `list_tunnels` hides server tunnel rows unless `include_vps=1`. These rules work on every plan, need no `firewall_edit`, and do not count against the device `firewall_rules` quota; each server has its own cap (`firewall_rules_used` / `firewall_rules_max` on `vps_list` and `vps_get`, per plan in `vps_catalog` `pricing.firewall_rules_per_server`; the two default ICMP rules do not count). At the cap `firewall_rule_add` answers 409 `vps_firewall_limit` with `used`, `max`, `fix`, `upgrade_url`. Turning the server's firewall off (`update_tunnel` `firewall=0`) also needs no `firewall_edit`.
- Gauges: `/api/stats/vps` (see Stats API), keyed by `tunnel_token`; `latest` entries carry `vps_id`.

---

## Endpoints outside the manifest

The live manifest is the list of the API: an endpoint that is not in it is not part of the API, and the skills do not call it. Accounts and recovery codes are managed in the portal at https://app.doxx.net.

---

## Stats API

`POST https://secure-wss.doxx.net/api/stats/<endpoint>` (GET works too). Params go in the **query string**, for GET and POST alike; a POST body is ignored. Auth (except `global`): the account token in the `X-Auth-Token` header (preferred: it stays out of URLs and logs). The `auth_token` and `token` query params also work but leak into logs: do not use them. The header and the URL go to curl as a config on stdin (`-K -`), so neither the token nor a `tunnel_token` param is in the curl command line. Errors are plain text, not JSON: 401 (no or bad token), 403 (`tunnel_token` not yours), 400 (bad param), 405.

Stats answers are keyed by `tunnel_token`, a credential: a top-level `tunnel_tokens` list, a `tunnel_token` on each row, `by_tunnel` maps keyed by token. **Never print a Stats answer raw.** The `network-stats` skill carries the recipe that fetches tunnel names with `list_tunnels` and replaces every token with a name. A bare call looks like this (for orientation only: pipe the result through `jq` before you show anything):

```
printf 'header=X-Auth-Token: %s\nurl=%s\n' "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" "https://secure-wss.doxx.net/api/stats/summary?days=7" | awk -v n=2 '{s = ""; for (i = 1; i <= length($0); i++) {c = substr($0, i, 1); s = s (c == "\\" || c == "\"" ? "\\" : "") c}; k = index(s, "="); o = o substr(s, 1, k - 1) " = \"" substr(s, k + 1) "\"\n"} END {if (NR == n) printf "%s", o}' | curl -s -K - -X POST
```

Times (`start`, `end`) are RFC3339 in UTC with a `Z` (`2026-11-17T08:00:00Z`): a `+00:00` offset breaks in a URL. Data lives in memory for at most 30 days. `bandwidth`, `alerts` and `summary` cover tunnels only; `/api/stats/vps` covers cloud servers only.

### /api/stats/bandwidth
Throughput over time, peak Mbps per time bucket. Example query: `bandwidth?start=2026-11-17T08:00:00Z&end=2026-11-17T09:00:00Z`.

Optional: `tunnel_token` (one tunnel; 403 if it is not yours), `start`, `end`. With no `start` it returns the last hour; **there is no `last` param.** Bucket size follows the range: 1s (up to 90 s), 1m (up to 2 h), 5m (up to 30 h), 1h (up to 8 days), 6h (longer). Returns `tunnel_tokens`, `requested` (`start`, `end`), `actual` (`start`, `end`: unix times of the first and last point, 0 when none), `granularity`, `data[]` (`tunnel_token`, `timestamp`, `peak_in`, `peak_out`, `samples`) and `aggregate[]` (the same summed across tunnels, with `tunnel_token` set to `aggregate`).

### /api/stats/alerts
Security alerts and DNS blocks. Example query: `alerts?last=1d`.

Optional: `last` (`1m`, `1h`, `1d` or `24h`, `7d`, `30d`, `session`), or `start` (with optional `end`) instead; `type` (an event type, for example `dns_block` or `security_event`); `tunnel_token`. With no time params it covers the last 24 hours. `last=session` **requires** `tunnel_token` (400 without) and counts from the start of the app's Live Activity session on that tunnel (iOS); with no session it gives zero counts. Put a `tunnel_token` in the URL only for this case (the URL lands in server logs): resolve it by name inside the shell and never print it. Returns `start`, `end`, `granularity`, `block_count`, `category_counts` (DNS block categories such as `ads`, `tracking`, `malware`, `other`; every security event rolls up into `security`), `totals` (count per event type), `data[]` sorted by count (`tunnel_token`, `prefix`, `type`, `action`, `value`, `note`, `category`, `timestamp`, `count`, `last_seen`) and `tunnel_tokens`; with `last=session` also `session_start` and `is_session`. For a security event, `value` says what it was (`dangerous_port`, `port_scan`, `dns_bypass`, `doh_bypass`).

### /api/stats/summary
Peak bandwidth and alert totals for a period. Example query: `summary?days=7`.

Optional: `days` (default 30; data older than 30 days is gone), `tunnel_token`. Returns `days`, `tunnel_tokens`, `bandwidth` (`total_peak_in`, `total_peak_out`: the highest single-tunnel peak in Mbps, not a sum; `total_samples`; `by_tunnel`: `peak_in`, `peak_out` keyed by `tunnel_token`) and `alerts` (count per event type).

### /api/stats/vps
Cloud server gauges (CPU, memory, disk, network). Example query: `vps?latest_only=1`.

Optional: `tunnel_token` (one server; omit for all), `start`, `end` (default: the last hour), `latest_only=1` (only the newest frame per server). Granularity: 5s up to 10 minutes, then 1m, 5m, 1h, 6h. Returns `status`, `now`, `tunnel_tokens`, `requested`, `actual`, `granularity`, `data` (per server and bucket: `metrics.<name>.{last,peak,min}` and `samples`) and `latest` (newest frame per server: `ts`, `age_s`, `vps_id`, `disk_src`, flat `metrics`). Metric names: `cpu`, `mem_used`, `mem_total`, `disk_used`, `disk_total`, `in`, `out`, `rd`, `wr`. A server with no frame in the retention window has no entry: that is "no data", not an error. Server liveness comes from `vps_get` `state`, not from `age_s`.

### /api/stats/global (no auth)
The global count of threats blocked across all doxx.net users.
```
curl -s "https://secure-wss.doxx.net/api/stats/global"
```
Returns `status`, `total`, `ts`.

---

## DNS infrastructure

| Layer | Address | Purpose |
|-------|---------|---------|
| Tunnel recursive | `10.10.10.10`, `fd53::` | Tunnel clients: personalized blocking, DNSSEC, resolves all doxx.net TLDs |
| Public recursive | `207.207.200.200`, `207.207.201.201` | Anyone: resolves the doxx.net TLDs and internet domains |
| Public recursive IPv6 | `2602:f5c1::` (Americas), `2a11:46c0::` (Europe) | Same, IPv6 |
| DoH | `https://doxx.net/dns-query` | DNS-over-HTTPS (public) |
| DoT | `doxx.net:853` | DNS-over-TLS (public) |
| Authoritative | `a.root-dx.net` / `.com` / `.org` | Nameservers for hosted domains |

Verify DNS: `dig A mysite.doxx @a.root-dx.net +short`. Resolve from anywhere: `dig A mysite.doxx @207.207.200.200 +short`.

## Known manifest errors

Where the live manifest (as of 2026-11-17) still disagrees with the handler code, this file follows the code:

- `create_tunnel`: the handler requires `type` (the manifest says it defaults to `wireguard`; only `create_tunnel_mobile` and `create_native_tunnel` default it) and returns only `message` and `tunnel_token`, not the full WireGuard configuration the manifest describes: fetch that with `wireguard`.
- `get_profile`: returns a `profile` object (`recovery_email`, `recovery_phone`, `email_notifications`, `sms_notifications`, `created_at`, `updated_at`) and `recovery_codes_count`, not the flat `email`, `phone` and notifications flag the manifest names.
- `update_proxy_config`: the params are `enabled`, `location`, `browser`, `hardware`, not `cloud_proxy_*`.
- `import_domain`: there is no `validation_code` param.
- `set_mobile_options` and `get_mobile_options`: `transport` is `normal`, `wss`, `sip`, `icmp`, `quic`, `cloudflare` or `https`, not `stealth` or `obfuscated`; `connection_profile` is `security`, `tinfoilhat`, `streaming`, `censorship` or `custom`, not `speed`; extra params `firewall`, `tcp_fingerprint`, `ipv4_public_enabled`; `get_mobile_options` nests its fields under `mobile_options`.
- `list_agents`: the manifest does not list `host_tunnel_name` and `host_tunnel_token`, which a hosted agent's entry carries. Treat `host_tunnel_token` as a credential when it is present.
- `device_list_unified`: an object (`my_devices`, `guest_accounts`, `subscription`), not an array.

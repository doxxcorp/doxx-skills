---
name: manage-tokens
description: "Manage doxx.net auth tokens: create, revoke, update roles, device tokens bound to a tunnel or agent, geo/IP fences, and tunnel scoping"
version: 1.2.0
homepage: https://github.com/doxxcorp/doxx-skills
user-invocable: true
metadata:
  openclaw:
    requires:
      env: [DOXX_TOKEN]
      bins: [curl, jq]
    primaryEnv: DOXX_TOKEN
---

# Manage doxx.net Tokens

You help users manage their doxx.net auth tokens: create scoped tokens for agents or team members, revoke compromised tokens, set expiration, restrict by country or IP, and limit to specific tunnels.

User request: $ARGUMENTS

## Calling the API

The doxx.net Config API describes itself. Fetch the live manifest with `curl -s https://config.doxx.net/` (a GET, no token; it lists every endpoint with params, returns, auth and side effects): this file is a snapshot.

**Config API**: every call is `POST https://config.doxx.net/v1/`, form-encoded: the endpoint as `<endpoint>=1`, its params, and the account token as `token`. The token goes in through stdin (`--data-urlencode "token@-"`), so it is not in the curl command line either:

```
printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value" --data-urlencode "token@-"
```

- Responses are JSON with `status` set to `success` or `error`. HTTP 200 can still be an error: always check `status`.
- Every response carries a `context` field: what happened, what the params mean, what to do next. Read it before you guess.
- Pass values that may hold spaces or symbols (JSON, PEM, config text) with `--data-urlencode "name=value"`.
- Check `command -v jq` before the first read. If jq is missing, do not call reads whose answers carry secrets (`list_tunnels`, `user_list_tokens`, `vps_*`, Stats): without jq they cannot be filtered. Ask the user to install jq (`brew install jq` on macOS, `sudo apt install jq` on Debian/Ubuntu) first.

### The token

**Auth token: it never enters the AI conversation.**

The shell expands the token and pipes it into curl, so its value stays on this machine: it never appears in a tool call, in the curl arguments or in the process list. Use the `printf %s "..." | curl ... --data-urlencode "token@-"` form above exactly as written in every call (curl reads stdin only once, so every other param goes on the command line, except the secret params below). The expansion takes the first non-empty source of four, in this order:

1. `DOXX_TOKEN` env var: the user exports it before launching the agent.
2. `~/.config/doxx/token` file (skipped when empty or missing).
3. `DOXXNET_TOKEN` env var (legacy name, still read).
4. `~/.config/doxxnet/token` file (legacy path, still read).

The files are read with `grep -m1 -s .`, not `cat`: it prints only the first non-empty line, so a stray second line in the file never reaches curl, and it fails on an empty or missing file, so the next source is tried.

Never echo, print, `cat` or log the token on its own, and never write it into a file the user did not ask for.

`tunnel_token` values (from `list_tunnels` and others) are credentials too. Use them inside calls, but refer to tunnels by name when you talk to the user and never print a `tunnel_token`.

**Secret params** (`tunnel_token`, `target_token`, any other credential) must not go on the command line either: every user of the machine can read a command line in the process list. Send them with the token through stdin, as a curl config (`-K -`):

```
printf 'url=https://config.doxx.net/v1/\ndata-urlencode=token=%s\ndata-urlencode=tunnel_token=%s\n' "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" "$tt" | awk -v n=3 '{s = ""; for (i = 1; i <= length($0); i++) {c = substr($0, i, 1); s = s (c == "\\" || c == "\"" ? "\\" : "") c}; k = index(s, "="); o = o substr(s, 1, k - 1) " = \"" substr(s, k + 1) "\"\n"} END {if (NR == n) printf "%s", o}' | curl -s -K - -X POST -d "ENDPOINT=1&param=value"
```

The `printf` writes one `option=value` line per curl option, and the `awk` turns each line into `option = "value"` with `\` and `"` escaped, so a value cannot end its quotes. `n` is the number of lines the `printf` writes. If the count differs (a value that holds a line break would add a line, and with it a curl option of its own), the `awk` prints nothing: curl then has no URL and sends nothing at all. The URL is in the config for that reason. For each secret param, add one `data-urlencode=NAME=%s\n` line and one argument, and add 1 to `n` (here `$tt` is a shell variable that holds the tunnel's token). Params that are not secret stay in `-d`. Never type a token value into this command: let the shell fill it in from a variable.

**Check the token** (prints only the API answer, never the token; on success it includes the token's `role`):

```
printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "auth=1" --data-urlencode "token@-"
```

**No token, or the check fails:** ask the user to:

1. Create a token in the portal at https://app.doxx.net: Account > Auth Tokens, role **Network Admin**, expiry 7 to 30 days. Admin is needed only to manage tokens or billing.
2. Save it on this machine themselves, in their own terminal, with mode 0600. For example (the paste is not shown on screen):
   `mkdir -p ~/.config/doxx && (umask 077 && read -rs t && printf %s "$t" > ~/.config/doxx/token)`
   Or `read -rs DOXX_TOKEN && export DOXX_TOKEN` before starting the session (the paste is not shown and stays out of the shell history).

Pasting the token into the chat is the last resort. If the user pastes it anyway, do not repeat it in any reply, log or file name, and suggest a short expiry and revoking it when the session ends.

### MCP tools

If doxx MCP tools are available in this session (tool names equal endpoint names), you may call them instead of curl: the server injects the token. Everything else in this file (params, errors, rules) applies the same way.

## Operating rules

You operate the user's network for them. Follow these rules on every task:

1. **Be transparent.** Tell the user which endpoints you call and what each call changed. Show the raw request if they ask (with the token expansion, never the token value).
2. **Secrets stay secret.** Auth tokens and `tunnel_token` values are credentials. Refer to tunnels by name; never print either kind of token.
3. **Read before you write.** List the current state first (for tunnels: `list_tunnels`) and keep the old values, so you can restore any setting you did not mean to change.
4. **Know the mutation semantics.** `update_tunnel` is a PATCH: it changes only the fields you pass. `apply_mode` is a REPLACE: every setting you omit resets to its default, the tunnel detaches from its saved profile, and profile-reserved IPs (a dedicated public IPv4 too) are released. `load_profile` also replaces all tunnel settings, with the profile's snapshot. Never use either to change one setting.
5. **Misspelled fields are often ignored.** Only `apply_mode` refuses settings keys it does not know (400, nothing applied). Other writes, such as `update_tunnel`, `set_mobile_options` and `update_saved_profile`, read a fixed list of fields and silently skip anything else: a misspelled flag gives "No changes to save" or even a success. After a write, read the state again (for tunnels: `list_tunnels`) and check that the value really changed. A field that only appears in list output is read-only status: do not try to set it.
6. **Some changes need a reconnect.** `requires_reconnect: true` or `needs_reconnect: true` in a response means the device must disconnect and reconnect (or re-import its WireGuard config) before the change is live. Tell the user, especially for headless or plain WireGuard devices that get no push updates.
7. **Source-IP pinning is fragile.** Consumer ISPs rotate public IPs (carrier NAT), and a device connected through a doxx.net tunnel arrives from its tunnel IP, not its home IP. Prefer port and protocol scoping, and warn the user before you pin `src_ip` to their current public address.
8. **Check entitlements before you act.** See "Plans and entitlements" (or call the entitlements MCP tool if one is present): locked features and full seats come back as errors, so look first and tell the user what is locked.
9. **Use the recipes.** For common goals (for example SSH into a machine behind NAT), the live manifest has a `use_cases` section with the exact calls in order and the pitfalls.

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

Any other error: a plain `message`, often with `context` and a `fix`. A bad or expired token fails every call: run the token check from "Calling the API".

Rules:

- Show `message`, `fix` and `upgrade_url` to the user verbatim. They are written for people.
- Never buy, subscribe, upgrade or add seats or add-ons on the user's behalf, even if a `fix` names a payments endpoint that would do it. Explain the options and let the user act in the portal.
- Do not retry a limit or plan error in a loop. It will not change until the user changes the plan or frees a resource.

## Roles

| Role | Can do |
|------|--------|
| `admin` | Everything, including token management, account deletion and billing |
| `net-admin` | All tunnel and network operations, creating and editing agents, and minting `device` credentials. No other token management |
| `read-only` | Reads only. This is the default when `create_token` gets no `role` |
| `device` | A gateway credential bound to one tunnel. It can identify itself (`auth`), fetch that one tunnel's WireGuard config and read that tunnel's firewall rules. Every other call is refused. doxxGateway setup mints it; users rarely need one by hand |

The token check (`auth`, see "Calling the API") returns the caller's `role`: run it first to know which calls will work.

Every endpoint below except `user_list_tokens` needs an `admin` token (a `net-admin` token may mint `role=device` only). A lower role gets `insufficient_role`.

## Token values are secrets

`user_list_tokens` returns every token in full, `create_token` returns the new one, and both carry `tunnel_token` values. Never print these responses raw. Show the user labels, roles and dates; keep the values inside the shell.

**List** (prints no token values; the tunnels a token is scoped to are counted, not shown):

```
printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "user_list_tokens=1" --data-urlencode "token@-" | jq '.tokens // [] | map({label, role, created_at, expires_at, revoked_at, is_current, geo_fence: [(.geo_fence // [])[].country], ip_fence: [(.ip_fence // [])[].cidr], scoped_tunnels: ((.tunnel_scope // []) | length)})'
```

An `admin` token sees every token on the account; a `net-admin` or `read-only` token sees only itself. Gateway (`device`) credentials are never in this list, not even for an `admin`: a `device` token gets an empty list (`tokens` is `null`), not itself. See "Gateway credentials" below.

**Act on one token** (`target_token`): pick it by its `created_at` (and label) from the list, and let the shell pass the value. This works only for tokens the list shows, so never for a `device` credential. Run it as one command, with `CREATED_AT` and the action replaced:

```
list=$(printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "user_list_tokens=1" --data-urlencode "token@-")
target=$(printf %s "$list" | jq -r --arg c "CREATED_AT" '[.tokens // [] | .[] | select(.created_at == $c)] | if length == 1 then .[0].token else empty end')
[ -n "$target" ] || { echo "no single token with that created_at"; exit 1; }
printf 'url=https://config.doxx.net/v1/\ndata-urlencode=token=%s\ndata-urlencode=target_token=%s\n' "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" "$target" | awk -v n=3 '{s = ""; for (i = 1; i <= length($0); i++) {c = substr($0, i, 1); s = s (c == "\\" || c == "\"" ? "\\" : "") c}; k = index(s, "="); o = o substr(s, 1, k - 1) " = \"" substr(s, k + 1) "\"\n"} END {if (NR == n) printf "%s", o}' | curl -s -K - -X POST -d "revoke_token=1"
```

**Create** (the new token goes into a private file, never into the conversation):

```
d=$(mktemp -d "${TMPDIR:-/tmp}/doxx-token.XXXXXX") || exit 1; chmod 700 "$d"
r=$(printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "create_token=1&role=net-admin&expires_at=EXPIRES_RFC3339" --data-urlencode "label=LABEL" --data-urlencode "token@-")
if [ "$(printf %s "$r" | jq -r .status)" = success ]; then
  (umask 077 && printf %s "$r" | jq -r .new_token > "$d/token"); echo "saved: $d/token"
else
  printf %s "$r" | jq -r '"error: " + (.message // "no message")'; rmdir "$d"
fi
```

The value is shown only once. Tell the user the printed path: they move the file to where the token is needed (for example `~/.config/doxx/token`, mode 0600, on the machine that uses it) and then delete it. Never `cat` the file. If they want to see the value, they run `cat` in their own terminal.

## Endpoints

### Listing
- `user_list_tokens`: list tokens (any role; see above for who sees what; `device` credentials are never listed, and `tokens` is `null` when the list is empty). Each has `token` (full value), `label`, `role`, `created_at`, `expires_at`, `revoked_at`, `is_current` (the calling token), `geo_fence[]` (`country`, `label`), `ip_fence[]` (`cidr`, `label`), `tunnel_scope[]` (`tunnel_token`, `label`)

### Creating and updating
- `create_token`: create a token. Optional: `label` (max 64 chars), `role` (`admin`, `net-admin`, `read-only` or `device`; **default `read-only`**), `expires_at` (RFC3339). Returns `new_token`. Always pass `role` and `expires_at` explicitly.
  - `role=device` needs `tunnel_token` (one of the account's tunnels) and takes an optional `agent_id`, which binds that agent to the tunnel's device (the tunnel must have a device hash). Returns `new_token`, `role`, `bound_tunnel` (a `tunnel_token`: do not print it) and `bound_agent_id`. A `net-admin` token may mint it.
- `update_token`: change label, role or expiry. Params: `target_token`. Optional: `label` (empty clears it), `role` (`admin`, `net-admin` or `read-only`), `expires_at` (RFC3339, or `never`). Works on an expired token (extend its expiry to bring it back), not on a revoked one. You cannot lower your own active token's role.
- `revoke_token`: revoke at once (soft). Params: `target_token`. Refused for your own active token and for the last active admin token. The token stays in the list with `revoked_at` set.
- `unrevoke_token`: re-enable a revoked token, with its role, fences and tunnel scope intact. Params: `target_token`. Fails if the token is not revoked.
- `delete_token`: delete a token and its fences and tunnel scope for good. Params: `target_token`. Same refusals as `revoke_token`.

### Geo fencing
When a token has geo fence entries, it works only from those countries (GeoIP lookup; a failed lookup lets the request through).
- `add_geo_fence`: params `target_token`, `country` (ISO 3166-1 alpha-2, for example `US`). Optional: `label`
- `remove_geo_fence`: params `target_token`, `country`. Removing the last entry removes the restriction.

### IP fencing
When a token has IP fence entries, it works only from matching addresses.
- `add_ip_fence`: params `target_token`, `cidr` (IPv4/IPv6 address or CIDR, for example `203.0.113.0/24`; a bare address becomes /32 or /128). Optional: `label`
- `remove_ip_fence`: params `target_token`, `cidr` (exactly as stored). Removing the last entry removes the restriction.

### Tunnel scoping
When a token has tunnel scope entries, it can see and change only those tunnels. With none, it reaches every tunnel on the account.
- `add_token_tunnel`: params `target_token`, `tunnel_token` (one of the account's tunnels). Optional: `label`. Get the `tunnel_token` from `list_tunnels` inside the shell, the same way as `target_token` above; talk about the tunnel by name.
- `remove_token_tunnel`: params `target_token`, `tunnel_token`. Removing the last entry gives the token every tunnel again.

Fences and scope can be changed only on a token that is active (not revoked, not expired).

## Gateway credentials

A `device` credential belongs to the agent host that minted it, so `user_list_tokens` does not show it, and the `created_at` recipe above cannot find it. Manage it through the agent instead (the `manage-agents` skill):

- `list_agents`: `credentials` is the number of live `device` credentials of each agent.
- `update_agent` with a new `host_device_hash`, or an empty one to unhost: revokes the old host's credentials for that agent at once.
- `delete_agent`: revokes the device credentials of the agent's host.

## Recovery codes revoke every token

Recovery codes are created in the portal (https://app.doxx.net/ops/account/profile), not here. When anyone redeems a recovery code, doxx.net assumes the account is compromised: **every token on the account is revoked at once**, agent gateway (`device`) credentials included, and one new `admin` token (label `Primary`) goes to whoever redeemed the code.

After a recovery, with that new admin token:

1. List the tokens (above): all are revoked, with their labels, roles and `created_at`. Gateway (`device`) credentials are revoked too but do not appear in the list, so you cannot pick them for `unrevoke_token` here.
2. Decide per token: trusted (`unrevoke_token`) or possibly compromised (leave it revoked, or `delete_token`).
3. If the compromise is not understood, add an IP fence before you re-enable a token.
4. Agent gateways need new device credentials: re-run the gateway's setup on each host. `list_agents` shows `credentials: 0` for an agent until its host has a new one.

## Guidelines

- List tokens first (labels, roles, dates only) before any change.
- For an AI agent or automation: `net-admin`, an expiry of 7 to 30 days, and an IP fence when it runs from a fixed address (servers, CI). Do not give it `admin` unless it must manage tokens or billing.
- Confirm with the user before `revoke_token` (whatever uses the token stops working at once) and before `delete_token` (irreversible).
- Warn before revoking a token that is in use: whatever uses it stops working at once.
- To rotate: create the new token first, move it into place, then revoke the old one. Never the other way round.
- `revoke_token` can be undone (`unrevoke_token`); `delete_token` cannot. Prefer revoke unless the user wants the token gone for good.
- Geo fences fail open: a failed GeoIP lookup lets the request through. Use an IP fence when the user needs a hard limit.

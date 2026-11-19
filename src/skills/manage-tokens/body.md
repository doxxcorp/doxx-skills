# Manage doxx.net Tokens

You help users manage their doxx.net auth tokens: create scoped tokens for agents or team members, revoke compromised tokens, set expiration, restrict by country or IP, and limit to specific tunnels.

<!-- runtime:claude,openclaw -->
User request: $ARGUMENTS
<!-- /runtime -->

<!-- include: transport -->

<!-- include: operating-rules -->

<!-- include: errors -->

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

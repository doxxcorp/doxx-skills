---
name: manage-agents
description: "Manage doxx.net agents: create, update and delete AI-agent chat principals (including webhook agents) for the doxxGateway, inspect device binding, clean up legacy bots"
version: 1.2.0
homepage: https://github.com/doxxcorp/doxx-skills
user-invocable: false
metadata:
  openclaw:
    requires:
      env: [DOXX_TOKEN]
      bins: [curl, jq]
    primaryEnv: DOXX_TOKEN
---

# Manage doxx.net Agents

You help users manage doxx.net **agents**: AI-agent chat principals that run on the doxxGateway. This skill covers the platform side through the Config API: create, list, edit, re-host and delete the agent. Running the agent (the doxxGateway binary, its local agent API) lives in the gateway repo, not here.

User request: $ARGUMENTS

## What an agent is

A doxx.net **agent** is an owned sub-friend of your account, not a separate account:

- **No new account.** An agent has a chat identity but no user, no login token and no bill of its own. Your devices see it as a friend; you see every conversation it has.
- **It is hosted on one of your devices.** The doxxGateway binary (https://github.com/doxxcorp/gateway) hosts it on a Linux machine (`kind=agent`, the machine takes its own device seat), or the doxx.net app hosts it on a Mac (`kind=device_agent`, sharing that Mac's seat). The host holds a `device` credential (`create_token role=device`), which the gateway's own setup mints. A `kind=webhook` agent is a post-only receiver hosted on one of your devices: outside systems post to it and the text lands in chat as the agent.
- **Plan gate.** Agents need the `agents` feature: Essentials and Pro include agents, Free does not. How many the plan allows is live in the entitlements (`limits.agents`; webhooks count too). The account also needs a profile name.
- **Owner-only by default.** New agents start `owner_only=1`: they reach you and nobody else. `update_agent owner_only=0` unlocks friend links. Even then every contact is **double opt-in**: the person must be your active friend AND accept the agent through an introduction.
- **Agent-to-agent chat is off** unless `a2a_enabled=1` is set on both agents.

**Two layers, do not mix them up.** This skill manages the agent's directory entry on doxx.net. The agent's own chat (send, wait for messages, files, contacts) is a separate API served by the gateway on its host. The gateway also speaks MCP for that chat API: point an MCP client at the command `doxxGateway mcp` (or `ssh <host> doxxGateway mcp`). Its tools (`chat_send`, `wait_for_message` and others) are chat tools, not network management.

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

## Plans and entitlements

Plans (the API calls Essentials `basic`):

- **Free**: an account plus mesh-only connectivity. Your own devices reach each other over the private network; there is no internet egress. P2P communications (chat, file transfer, calls) and one domain are included.
- **Essentials**: adds internet routing, DNS protection and blocklists, connection modes, device controls (kill switch, connect on startup) and agents.
- **Pro**: everything in Essentials, plus Pro-only features: firewall edits and port forwarding, custom DNS rules, premium blocklists, saved connections (profiles), onion routing, Web Privacy (proxy), DNS bypass protection, covert communications, Mesh Private Server (a private server on the user's Mac), and Remote Desktop (to the user's own Macs).
- **Pro+**: legacy, not sold.

Extra seats, agent seats, domains, dedicated IPv4 addresses and cloud servers (VPS) are add-ons. The cloud server add-on is sold on every plan, Free included. Never quote seat counts, limits or prices from memory: they change. Get live numbers:

- **This account** (plan, status, seats used and total, which features are on, per-resource limits):

  ```
  printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://payments.doxx.net/v1/access/status --data-urlencode "token@-"
  ```

  The answer is under `access`: `plan`, `status`, `total_seats`, `seated_devices`, `features` (name to true/false), `limits` (name to `used`/`max`).
- **Public price list** (no token): `curl -s https://payments.doxx.net/v1/pricing` returns `plans`, `addons` and a feature `comparison`.

Plan changes, seats and add-ons are the user's decision. Send them to the plan page at https://app.doxx.net/ops/account/subscription; never buy or change anything for them.

## Endpoints

- `create_agent` (net-admin): create an agent. Params: `agent_name` (required, max 64 chars: the friend name your devices show). Optional: `kind` (`agent` default, `device_agent` or `webhook`), `a2a_enabled=1`. Returns `agent_id`, `agent_name`, `kind`, `a2a_enabled`, `notes`. The agent is paired to you as a friend at once. No token is minted here.
  - Refusals: `feature_required` with `feature: "agents"` (no agents on this plan) or `feature: "p2p"` (the account has no chat at all, for example a paused one), `agent_limit` (all agent seats used), 400 "Set your profile name before creating an agent".
- `list_agents`: the account's agents. Each has `agent_id`, `agent_name`, `kind`, `a2a_enabled`, `owner_only`, `status`, `bound` (has a host), `credentials` (live device credentials for this agent), `pair_count`, `created_at`. A hosted agent also has `bound_device_hash`, `host_name` (same as `bound_device_name`), `host_os`, `host_tunnel_name`, `host_online` (the host's tunnel is up) and `host_tunnel_token` (a credential: never print it). Whether the agent is answering right now is not here: presence travels over the mesh.
- `update_agent` (net-admin): edit an agent. Params: `agent_id` (required). Optional, each independent (omitted fields stay): `agent_name` (rename; every pair sees the new name), `owner_only` (`1` or `0`), `a2a_enabled` (`1` or `0`), `host_device_hash` (move the agent to another of your devices: a `device_hash` from `device_list_unified`; an empty value unhosts it). Returns `agent_id`, `changed`, and a `note` on a re-host. The host gateway picks the change up within about a minute.
  - Re-hosting or unhosting **revokes the old host's credentials for this agent at once**: the old host stops speaking as the agent. The new host claims the agent on its next check and mints its own credential.
  - `motd` (the status line) is refused with 410: it travels over the mesh from the owner's device, not through this API. A deleted agent answers 410 too.
- `delete_agent` (admin): delete an agent you own. Revokes all its pairs and its device credential, clears its host. Params: `agent_id` (required). Returns: `deleted_agent_id`, `notes`. The device and tunnel remain (remove with `delete_tunnel`); the chat-identity certificate lives on the host and dies with it.

Show agents without their tunnel tokens, for example:

```
printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "list_agents=1" --data-urlencode "token@-" | jq '.agents // [] | map(del(.host_tunnel_token))'
```

### Legacy bots (deprecated)

Bot accounts are replaced by agents. `create_bot` returns **HTTP 410** (`create_bot_deprecated`). Use these only to inspect and clean up existing bots:

- `list_bots`: Returns `bots[]` with `bot_user_id`, `bot_name`, `tunnel_count`, `seated`, `online`, `created_at`.
- `delete_bot` (admin): delete a legacy bot and everything it holds (user row, token, profile, seat grant, pairs, tunnels). The seat returns to the plan. Params: `bot_user_id` (required). Irreversible.

## Guidelines

- Always call `list_agents` first before creating, editing or deleting.
- Before `create_agent`, check the entitlements (`agents` feature, `limits.agents`). On `feature_required` or `agent_limit`, show `message` and `upgrade_url` and stop; never buy seats.
- On `create_agent`, remind the user that hosting is a separate step: run the doxxGateway (https://github.com/doxxcorp/gateway) or the Mac app's Agent Gateway. Point them at the `chat_bot_gateway_for_ai_agents` recipe.
- Confirm before a rename or re-host with `update_agent`: a rename is seen by every pair; a re-host or unhost cuts the old host off at once.
- Confirm before `owner_only=0`.
- Only suggest `a2a_enabled=1` when the user wants agent-to-agent chat; it must be set on both agents.
- Confirm before `delete_agent` and `delete_bot` (irreversible).
- If a user asks to "create a bot," tell them bots are deprecated and create an agent instead.
- Never print `host_tunnel_token` or any credential from these responses; name the host device and tunnel instead.

---
name: manage-tunnels
description: "Manage doxx.net tunnels: create, update, move, delete devices and get WireGuard configs"
argument-hint: "[action] [tunnel name]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(printf *), Bash(jq *), Bash(chmod 600 *), Bash(umask 077), Bash(qrencode -o */doxx-wg.*/doxx-qr.png*), Bash(open */doxx-wg.*/doxx-qr.png), Bash(xdg-open */doxx-wg.*/doxx-qr.png), Bash(sudo install -m 600 */doxx-wg.*/doxx.conf /etc/wireguard/doxx.conf), Bash(rm -f */doxx-wg.*/doxx.conf */doxx-wg.*/doxx-qr.png), Bash(rmdir */doxx-wg.*), Bash(openssl *), Bash(dig *), Bash(sudo wg-quick up doxx), Bash(sudo wg-quick down doxx), Write
---

# Manage doxx.net Tunnels

You help users manage their doxx.net tunnels. Each tunnel represents a device on the network.

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

**IMPORTANT: token security. The token must never enter the AI conversation.**

The shell expands the token and pipes it into curl, so its value stays on this machine: it never appears in a tool call, in the curl arguments or in the process list. Use the `printf %s "..." | curl ... --data-urlencode "token@-"` form above exactly as written in every call (curl reads stdin only once, so every other param goes on the command line, except the secret params below). The expansion takes the first non-empty source of four, in this order:

1. `DOXX_TOKEN` env var: the user exports it before launching Claude Code.
2. `~/.config/doxx/token` file (skipped when empty or missing).
3. `DOXXNET_TOKEN` env var (legacy name, still read).
4. `~/.config/doxxnet/token` file (legacy path, still read).

The files are read with `grep -m1 -s .`, not `cat`: it prints only the first non-empty line, so a stray second line in the file never reaches curl, and it fails on an empty or missing file, so the next source is tried.

Never echo, print, `cat` or log the token on its own, and never write it into a file the user did not ask for.
Never use the `Read` tool on either token file: that loads the plaintext into the AI conversation and sends it with every later tool call. Use Bash only to pipe the expansion into curl as shown.

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
In that case, with the user's OK, you may save it once with the `Write` tool to `~/.config/doxx/token`, then run `chmod 600 ~/.config/doxx/token`, so later calls use the file.

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

## Batching calls (Code Mode)

For work that needs many reads, run one short program that makes the calls, joins and filters the answers in the shell, and prints only the summary. The conversation gets a few lines instead of raw JSON, the result is the same every time, and secrets such as `tunnel_token` never leave the shell.

**When to batch:**

- Three or more calls feed one answer (for example tunnels, stats and alerts for a status overview).
- A fan-out: the same call once per tunnel or per server.
- A large answer you need only a few fields from.
- Polling: waiting for a state to change.

**When to make single calls:** one question that one or two reads answer.

**Writes:**

- A single write is always one call, after the user confirms, with its `status` and `context` checked before the next call. A failure then never leaves a half-applied change.
- A bulk write (the same change on many tunnels) may run in a script, but the script must first print the planned calls as a dry run (endpoint, tunnel name and values, never a token). Show that plan to the user, and run it with `--apply` only after a clear yes. It still makes the calls one at a time and stops at the first error.

**Prefer the bundled scripts.** Some skills ship ready scripts in a `scripts/` directory, with their shared helper in `lib/`. `<skill dir>` below means the skill's root directory: the one that holds its `SKILL.md` (or `AGENTS.md`) and the `scripts/` and `lib/` directories. Run a script with `bash <skill dir>/scripts/<name>.sh`; each one takes `--help`, is read-only unless it says otherwise, and prints the endpoints it called. Write your own bash + curl + jq script only when no bundled script fits, and follow the same rules:

- Check `command -v jq` first: the scripts need `jq`. Without it, do not batch: make single calls, and none whose answer carries secrets (see "Calling the API").
- If `<skill dir>/lib/doxx.sh` exists, source it instead of writing curl calls by hand. `doxx_require` checks curl, jq and the token, and prints the endpoints called when the script ends. `doxx_call ENDPOINT key=value ...` (Config API) and `doxx_stats ENDPOINT key=value ...` (Stats API) put the answer in `$DOXX_OUT`, stop on an error with the API's message, and keep the auth token out of every command line. `doxx_names "$tunnels" "$answer" FILTER` maps tokens to tunnel names.
- Never print the auth token or a `tunnel_token`. Map tokens to tunnel names inside the script; if a token must be shown at all, show only its first 4 characters and "…".
- Make the calls one after another, never in parallel, and respect the rate limits (`network_info`: 30 calls a minute per account).
- Stop at the first error and print the API's `message` (Stats errors are plain text).
- At the end, print the list of endpoints the script called, so the user sees what ran.

## Endpoints

- `list_tunnels`: list all tunnels. Optional: `device_hash`, `device_type` (filters), `include_vps=1` (also return cloud server (VPS) tunnel rows, which are hidden by default). Each tunnel carries `name`, `server`, `assigned_ip`, `assigned_v6`, `public_ipv4` (when a dedicated IPv4 is bound), `is_connected`, `connection_status`, the settings flags (`firewall`, `ipv6_enabled`, `block_bad_dns`, `ip_options_filter` and the rest), `mode`, `active_profile_id`/`active_profile_name`, plus `tunnel_token` and the WireGuard `private_key`. The top level also has `mesh_public_pools`: the CIDRs of the dedicated public IPv4 pools. A source address inside one of them is a doxx.net device on a dedicated address (a friend's device included), not a stranger on the internet.
- `create_tunnel`: create a generic WireGuard tunnel (desktop, server, WireGuard app). Params: `server` (hostname from `servers`), `type=wireguard` (required: the call fails without it). Optional: `name` (max 64 chars), `profile_id`, and initial flags (`block_bad_dns`, `ipv6_enabled` and others, each 0 or 1). Returns `tunnel_token` only: fetch the config with `wireguard`.
- `create_native_tunnel`: create or refresh the tunnel of a doxx.net native iOS/Android/macOS app install. Params: `device_hash` (from `device_list_unified` or `list_tunnels`), `server`. Optional: `name`, `profile_id`. It reuses the device's existing tunnel. Moving it to a different server without `profile_id` detaches the tunnel's saved profile: pass `profile_id` to keep it.
- `create_tunnel_mobile`: the app's alias of `create_tunnel` (needs `device_hash`). Do not use it for generic WireGuard clients: use `create_tunnel`.
- `update_tunnel`: PATCH a tunnel. Params: `tunnel_token` (required); any of `name`, `server`, `mode` (empty string clears it), and the 0/1 flags `firewall`, `ipv6_enabled`, `block_bad_dns`, `block_doh_dot`, `bandwidth_stats`, `security_stats`, `keep_established_ssh`, `kill_default_route`, `auto_reconnect`, `enable_routing`, `snarf_dns`, `onion_enabled`, `mtu_spoofing`, `ip_options_filter`. Returns 423 when the tunnel's saved profile has a settings lock.
- `delete_tunnel`: delete a tunnel and free its addresses (permanent; active connections drop at once). Params: `tunnel_token`
- `wireguard`: get the WireGuard config (generic WireGuard tunnels only: do NOT call on native app tunnels). Params: `tunnel_token`
- `servers`: list available servers (no auth needed)

## Plan gates on tunnel settings

- **Connecting:** every plan connects. Free accounts (and lapsed ones, which are Free) get mesh-only routing: their own devices reach each other, with no internet egress. Only a paused, revoked or suspended account is refused, with `feature_required` and `feature: "connect"` (see Errors). A full set of device seats returns `seat_limit` (409).
- **`update_tunnel` 403s:** turning ON `onion_enabled` (Onion Routing) or `block_doh_dot` (DNS Bypass Protection) needs the matching Pro feature. Turning the firewall OFF (`firewall=0`) needs `firewall_edit` (Pro); turning it on is always allowed. Turning the firewall off also deletes that tunnel's firewall rules: warn the user first.
- **`ip_options_filter`** (default 1, any plan may change it): the server drops inbound connection attempts that carry risky IPv4 options or IPv6 extension headers, and strips MPTCP negotiation, toward this tunnel. Suggest `0` only when the user runs MPTCP or source-routed diagnostics behind a port forward. It is not part of saved profiles or modes.

## Client installation

**Get the config without exposing the key.** The `wireguard` response holds the tunnel private key, so it must never reach the conversation. Keep the response in a shell variable, print only its status, and build `doxx.conf` with `jq` inside a private temp directory (mode 700, never the current directory: it could be a git repo). This needs `jq` (`command -v jq`; if missing: `brew install jq` on macOS or `sudo apt install jq` on Debian/Ubuntu). Run it as one command, with `NAME` replaced by the tunnel's name: the first two lines find the tunnel's token by name inside the shell, without printing it.

```
tt=$(printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "list_tunnels=1" --data-urlencode "token@-" | jq -r --arg name "NAME" '[.tunnels[]? | select(.name == $name)] | if length == 1 then .[0].tunnel_token else empty end')
[ -n "$tt" ] || { echo "no single tunnel named NAME"; exit 1; }
d=$(mktemp -d "${TMPDIR:-/tmp}/doxx-wg.XXXXXX") || exit 1; chmod 700 "$d"; echo "dir: $d"
r=$(printf 'url=https://config.doxx.net/v1/\ndata-urlencode=token=%s\ndata-urlencode=tunnel_token=%s\n' "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" "$tt" | awk -v n=3 '{s = ""; for (i = 1; i <= length($0); i++) {c = substr($0, i, 1); s = s (c == "\\" || c == "\"" ? "\\" : "") c}; k = index(s, "="); o = o substr(s, 1, k - 1) " = \"" substr(s, k + 1) "\"\n"} END {if (NR == n) printf "%s", o}' | curl -s -K - -X POST -d "wireguard=1")
if [ "$(printf %s "$r" | jq -r .status)" = success ]; then
  (umask 077 && printf %s "$r" | jq -r '.config | "[Interface]\nPrivateKey = \(.interface.private_key)\nAddress = \(.interface.address)\n\(if (.interface.dns // "") != "" then "DNS = \(.interface.dns)\n" else "" end)\n[Peer]\nPublicKey = \(.peer.public_key)\nAllowedIPs = \(.peer.allowed_ips)\nEndpoint = \(.peer.endpoint)\nPersistentKeepalive = \(.peer.persistent_keepalive)"' > "$d/doxx.conf")
  printf %s "$r" | jq -r 'if .requires_reconnect then "success (requires_reconnect)" else "success" end'
else
  printf %s "$r" | jq -r '"error: " + (.message // "no message")'
  rmdir "$d"
fi
```

The config is built only when `status` is `success`; on an error, show the user the printed `message`. A mesh-only tunnel (an account without internet access through doxx.net) gets an empty `dns`: the config then has no `DNS =` line, and the device keeps its own DNS. The command prints the directory path: below it is called `DIR`; use the printed path literally in later commands. Never `cat` `DIR/doxx.conf`, and never print the private key or the full config in the chat. If you create a key-bearing file with an editor tool (such as Write) instead of the shell, `umask` does not apply: run `chmod 600` on it right after writing.

**macOS or Linux, this machine:** `sudo install -m 600 DIR/doxx.conf /etc/wireguard/doxx.conf && sudo wg-quick up doxx`. To disconnect: `sudo wg-quick down doxx`. Always use the interface name `doxx` (the file `/etc/wireguard/doxx.conf`). The WireGuard tools are optional: they are needed only for this step. Check with `command -v wg-quick`; if missing, give the install command (`brew install wireguard-tools` on macOS, `sudo apt install wireguard-tools` on Debian/Ubuntu) or offer the other options below.

**Phone with the WireGuard app (generic tunnel, not the doxx.net app):** offer the user the options that are available here, in this order (there is no server-side QR: never send the config anywhere to render it):

1. **Local QR code** (preferred: nothing leaves this machine). Check with `command -v qrencode`. If it is missing, give the install command: `brew install qrencode` (macOS) or `sudo apt install qrencode` (Debian/Ubuntu). Then write an image and open it for the user:
   `(umask 077 && qrencode -o DIR/doxx-qr.png < DIR/doxx.conf)`, then `open DIR/doxx-qr.png` (macOS) or `xdg-open DIR/doxx-qr.png` (Linux).
   Never run `qrencode -t ansiutf8` yourself: its output would put the config into the conversation. If the user wants the code in a terminal, give them `qrencode -t ansiutf8 < DIR/doxx.conf` to run in their own terminal. They scan it in the WireGuard app (Add tunnel > Scan from QR code).
2. **The file itself.** The user moves `DIR/doxx.conf` to the phone over a channel they trust and imports it in the WireGuard app (Add tunnel > Import from file).

**Clean up** once the device has imported the tunnel: `rm -f DIR/doxx.conf DIR/doxx-qr.png && rmdir DIR`. If you cannot run it (for example the user denies the command), tell the user that `DIR` holds the tunnel private key and that they should delete it themselves.

## Guidelines

**Tunnel type guide: important:**
- doxx.net native app → `create_native_tunnel` (requires `device_hash`). No WireGuard config or QR code needed: the app handles the connection. The tunnel record `type` still shows `"wireguard"` (the protocol); "native" is a client distinction, not a record field.
- Generic WireGuard client (WireGuard app, any platform) → `create_tunnel` with `type=wireguard`, then `wireguard` to fetch the config, then deliver it to the device (see Client installation).
- Never call `wireguard` on a native-app tunnel. If a user asks for a WireGuard QR and has a native tunnel, clarify which type they need.

- Always list tunnels first to show current state before making changes. `list_tunnels` output holds `tunnel_token` and `private_key` values: extract only the fields you show (for example with `jq '.tunnels[] | {name, server, assigned_ip, connection_status}'`), never the raw JSON.
- After `create_tunnel`, call `list_tunnels` to show the new tunnel's name, server and address. Never show its `tunnel_token`.
- When creating tunnels, suggest the nearest server based on the user's context
- When moving a tunnel to a new server, explain that the WireGuard config changes and must be re-installed
- To change one setting, use `update_tunnel` with only that field (never `apply_mode` or `load_profile`: see Operating rules)
- Confirm with user before deleting tunnels

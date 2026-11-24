---
name: manage-firewall
description: "Manage doxx.net firewall rules: open ports, port forwards, link tunnels for mesh networking, manage access rules"
argument-hint: "[action] [details]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(bash */manage-firewall/scripts/firewall-audit.sh*), Bash(printf *), Write
---

# Manage doxx.net Firewall

You help users manage firewall rules on their doxx.net tunnels. This controls which tunnels can talk to each other (mesh networking) and which ports are open to the internet.

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
| `profile_in_use` | 409 | `in_use_by` (device name), `in_use_tunnel_token`, `in_use_server`, `profile_id`, `release_action` | The profile is live on another connected tunnel: it is bound there, or that tunnel holds one of the profile's reserved addresses. Show `message`. `in_use_tunnel_token` is a credential: never print it. To name the tunnel, match it against `list_tunnels` inside the shell and show only the `name`. Never act on `release_action`: it describes a call outside the public API. Tell the user to disconnect that tunnel (by name, on `in_use_by`) or pick another profile. Other profile and address calls (lock, unlock, release, lease) answer the same conflict with the key `error` and only `in_use_by`. |
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

**Fast path for "show my firewall" or a review:** `bash <skill dir>/scripts/firewall-audit.sh` prints every rule of every tunnel and cloud server by name, and flags ports open to the whole internet (`OPEN`, `OPEN-ALL` for every port), sources pinned to one public address (`PINNED-SRC`), tunnels with the firewall off (`FIREWALL-OFF`), and rules that are kept but not enforced (STATE `disabled`), plus the Full Mesh state. With Full Mesh on it calls `firewall_rule_list` once per tunnel, one at a time, and the rules Full Mesh parked are not listed at all: the API does not return them in that mode, so their only count is `rules_dormant` from the `firewall_link_all_toggle` answer.

## Endpoints

- `firewall_rule_list`: list firewall rules. Optional: `tunnel_token`. Returns `link_all_enabled`, `rules[]` (each with `protocol`, `src_ip`, `src_port`, `dst_ip`, `dst_port`, `enabled`, and the rule's `tunnel_token`: do not print it), `count`. With Full Mesh off, a call without `tunnel_token` lists every rule of the account. With Full Mesh on, **send a `tunnel_token`**: without one the answer is `rules: null`, `count: 0`, even when rules exist. Each per-tunnel call then lists only that tunnel's enforced rules (in practice the inbound rules from outside the account), plus `user_tunnel_ips`. `rules` is JSON `null`, not `[]`, whenever there are none, in both modes: always read it as `.rules // []`.
- `firewall_rule_add`: add a rule. Params: `tunnel_token`, `src_ip`, `dst_ip`. Optional: `protocol` (TCP/UDP/ICMP/ALL, default ALL), `src_port`, `dst_port` (a port, a range like `8000-8100`, or ALL; default ALL), `purpose=port_forward` (when the rule is a port forward, so a plan refusal names Port Forwarding). The destination must be one of the account's addresses. Needs the `firewall_edit` feature (Pro); `purpose=port_forward` checks `port_forwarding` (also Pro). The plan's rule quota answers 409 "Firewall rule limit reached"; an identical rule answers 409 "already exists". A cloud server's own `tunnel_token` is the exception: see "Cloud servers (VPS)".
- `firewall_rule_delete`: delete a rule. All six params are required and have no defaults: `tunnel_token`, `protocol`, `src_ip`, `src_port`, `dst_ip`, `dst_port`. Copy each value from the rule as `firewall_rule_list` shows it, and send `ALL` explicitly where the rule has `ALL` (a rule added without a protocol or ports has `ALL` there). A missing param answers 400; values that match no rule answer 404 "Firewall rule not found": list the rules again and copy the values exactly.
- `firewall_link_all_toggle`: turn Full Mesh (link all tunnels) on or off. Params: `enabled` (1 or 0). Available on every plan, Free included. Returns `link_all_tunnels`, `rules_dormant`, `rules_restored`.
- `firewall_link_all_status`: check if Full Mesh is on
- `list_tunnels`: list tunnels (to get assigned IPs for rules)

## Full Mesh and existing rules

Turning Full Mesh on does not delete tunnel-to-tunnel rules: it parks them (kept, not enforced) and reports how many in `rules_dormant`. While Full Mesh is on, `firewall_rule_list` does not return parked rules at all, so `rules_dormant` is the only count: tell the user that number when you turn Full Mesh on. Turning it off restores them (`rules_restored`). Inbound rules from outside the account are not touched. While Full Mesh is on, new tunnel-to-tunnel rules are refused (they would be redundant); inbound rules still work.

## Firewall on/off per tunnel

Every tunnel's firewall is on by default (default deny). Turning it off is `update_tunnel` with `firewall=0`: it needs `firewall_edit` (Pro), except on a cloud server's own tunnel, and deletes that tunnel's rules. Prefer adding a specific rule.

## Cloud servers (VPS)

A cloud server's public addresses use the same `firewall_rule_add` / `firewall_rule_delete` / `firewall_rule_list` calls, with the server's own `tunnel_token` (from `vps_create`, or from `list_tunnels` with `include_vps=1`). A new server answers only ping from the internet until ports are opened this way.

A server's firewall is part of the cloud server add-on, so its own `tunnel_token` follows different rules from a device tunnel:

- Rules on it work on **every plan**: no `firewall_edit` (Pro) is needed, and they do not count against the device firewall rule quota.
- Each server has its **own cap** instead. `vps_list` and `vps_get` show `firewall_rules_used` and `firewall_rules_max` per server (`-1` is no cap); `vps_catalog` shows the cap per plan in `pricing.firewall_rules_per_server`. The two default ICMP rules do not count.
- At the cap, `firewall_rule_add` answers 409 with `error_code` `vps_firewall_limit` and `used`, `max`, `fix`, `upgrade_url`. Show `message` and `fix`, offer to remove a rule the user no longer needs, and mention that a higher plan raises the cap (`upgrade_url` is a portal path: show it as `https://app.doxx.net` plus that path). Do not retry.

## Common patterns

**Home server accessible from all devices:**
1. Enable Full Mesh: `firewall_link_all_toggle=1&enabled=1`
2. Open specific ports to internet if needed (e.g., 443 for web server)

**Only laptop + phone can see each other:**
1. Keep Full Mesh off
2. Add bidirectional rules between the two tunnels

**Open SSH on a server tunnel:** run it as one command, with `NAME` replaced by the tunnel's name and `TUNNEL_IP` by its address. The first two lines find the tunnel's token by name inside the shell, without printing it (for a cloud server, use "One server by name" in the `manage-vps` skill instead):

```
tt=$(printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "list_tunnels=1" --data-urlencode "token@-" | jq -r --arg name "NAME" '[.tunnels[]? | select(.name == $name)] | if length == 1 then .[0].tunnel_token else empty end')
[ -n "$tt" ] || { echo "no single tunnel named NAME"; exit 1; }
printf 'url=https://config.doxx.net/v1/\ndata-urlencode=token=%s\ndata-urlencode=tunnel_token=%s\n' "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" "$tt" | awk -v n=3 '{s = ""; for (i = 1; i <= length($0); i++) {c = substr($0, i, 1); s = s (c == "\\" || c == "\"" ? "\\" : "") c}; k = index(s, "="); o = o substr(s, 1, k - 1) " = \"" substr(s, k + 1) "\"\n"} END {if (NR == n) printf "%s", o}' | curl -s -K - -X POST -d "firewall_rule_add=1&protocol=TCP&src_ip=0.0.0.0/0&src_port=ALL&dst_ip=TUNNEL_IP&dst_port=22" | jq '{status, message}'
```

**SSH into a NAT'd / headless box over the mesh (least privilege):**
- Add a single TCP:22 rule between just the two tunnel IPs (client -> server) instead of enabling Full Mesh. This is the per-pair pattern behind agent-to-agent reach and the `ssh_to_server_behind_nat` recipe in the live manifest's `use_cases`.

## Guidelines

- Always list current rules before making changes
- Get tunnel IPs from `list_tunnels`: you need the `assigned_ip` for rules
- For mesh networking between two tunnels, always create bidirectional rules (A->B and B->A)
- Confirm with the user before `firewall_rule_delete` and before `update_tunnel` with `firewall=0` (it turns the tunnel's firewall off and deletes its rules)
- Prefer Full Mesh over manual rules when the user wants every device to reach every other device
- Adding rules to a device tunnel is a Pro feature (Full Mesh is not, and neither are rules on a cloud server's own tunnel): check live entitlements before planning a rule-based setup, and on `feature_required` show the `upgrade_url` instead of retrying

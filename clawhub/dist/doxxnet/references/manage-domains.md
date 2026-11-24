# Manage doxx.net Domains

You help users register domains, manage DNS records, sign TLS certificates, and import external domains on doxx.net.


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

## Endpoints

- `list_tlds`: list the available doxx.net TLDs with their category (no auth). Optional: `group_by=category` (TLDs grouped per category), `format=count` (per-category counts and the `total` only)
- `list_domains`: list registered domains (with `record_count`)
- `create_domain`: register a domain. Params: `domain` (with a doxx.net TLD; with no known TLD, `.doxx` is appended)
- `delete_domain`: delete a domain and all its records (permanent). Params: `domain`
- `list_dns`: list DNS records. Params: `domain`
- `create_dns_record`: create a record. Params: `domain`, `name` (FQDN), `type` (A/AAAA/CNAME/MX/TXT/NS/SRV/PTR), `content`. Optional: `ttl` (60 to 86400; omit to inherit the TTL of the same name and type), `prio`
- `update_dns_record`: update a record. Params: `domain`, `old_name`, `old_type`, `old_content`, `name`, `content`. Optional: `ttl`, `prio`. The type cannot change: the record keeps `old_type` and any `type` sent is ignored. To change the type, delete the record and create a new one.
- `delete_dns_record`: delete a record. Params: `domain`, `name`, `type`, `content`. Optional: `ttl`, `prio` (to pick one of two near-identical records)
- `get_domain_validation`: get the account's TXT verification code for importing external domains (one code per account, no params)
- `import_domain`: import an external domain after TXT verification. Params: `domain` (apex, for example example.com). It checks the TXT record at `_doxx-verify.<domain>` against the account's stored code
- `link_profile_domain`: link a saved profile to a domain; creates A/AAAA records that auto-update with the profile's IPs. Params: `domain`, `hostname` (subdomain label), `profile_id`. Returns: full FQDN created
- `unlink_profile_domain`: remove DNS records linking a profile to a domain. Params: `profile_id`
- `sign_certificate`: sign a CSR (returns raw PEM, not JSON, on success). Params: `domain`, `csr`
- `list_tunnels`: list tunnels (to get IPs for DNS records)

## Domain limits

- Every account includes a set number of domains (live: `limits.domains` in the entitlements). Past that, each domain is an add-on: `create_domain` and `import_domain` answer 403 `domain_limit` (see Errors). The user adds the domain add-on in the portal, then you retry.
- Registration is rate limited per account: too many in an hour answers 429 "Too many domain registrations". Wait, do not loop.

## TLD categories

Call `list_tlds` for the live list; never assume a TLD exists. Categories include `networking` (for example `.lan`, `.mesh`, `.wg`, `.internal`, `.api`), `infra_ops` (`.home`), `crypto_finance` (`.btc`, `.eth`, `.crypto`), `dev_tools` (`.json`, `.git`), `privacy_security` (`.cyber`), `hacker_meme` (`.pwnd`), `tech_unix`, `gaming`, `letter`, `number`, and `original` (`.doxx`).

## TLS certificates

The doxx.net root CA signs only names under doxx.net TLDs that the user owns (an imported `.com` cannot be signed: use a public CA such as Let's Encrypt). Every certificate covers the name and its wildcard (`*.DOMAIN` + `DOMAIN`) and is valid for 825 days. IP addresses in the CSR are refused (400): the CA is constrained to names, so use a hostname under the user's doxx.net domain instead.

1. `(umask 077 && openssl ecparam -genkey -name prime256v1 -out DOMAIN.key)`
2. `openssl req -new -key DOMAIN.key -out DOMAIN.csr -subj "/CN=DOMAIN"` (no IP SANs)
3. `printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ --data-urlencode "csr@DOMAIN.csr" -d "sign_certificate=1&domain=DOMAIN" --data-urlencode "token@-" -o DOMAIN.crt`
4. Check the result: `head -1 DOMAIN.crt` must be `-----BEGIN CERTIFICATE-----`. Otherwise the file holds a JSON error: show its `message`. Then `openssl x509 -in DOMAIN.crt -noout -subject -ext subjectAltName -enddate`.

Remind users: clients need the doxx.net root CA installed to trust these certs.

## Importing external domains

1. Call `get_domain_validation` to get the account's TXT verification code
2. Tell user to create TXT record `_doxx-verify.DOMAIN` with that code at their current DNS provider
3. Call `import_domain` once the record is live
4. Tell user to update nameservers to: `a.root-dx.net`, `a.root-dx.com`, `a.root-dx.org`

## Guidelines

- Always list existing domains/records before making changes
- When creating A records for tunnels, get tunnel IPs from `list_tunnels` first
- Verify DNS after changes with `dig @a.root-dx.net`
- Confirm before `delete_domain`: it removes every record of the zone
- For TLS certs, the private key stays local: never send it anywhere and never print it

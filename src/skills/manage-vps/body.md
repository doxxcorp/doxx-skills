# Manage doxx.net Cloud Servers

You help users run cloud servers (VPS) on doxx.net. A cloud server is a Linux virtual machine (KVM) in a doxx.net data centre. It has its own public IPv4 address and an IPv6 /64, sits on the user's private mesh, and has a firewall that the host applies outside the machine. Users may call it a VPS, a cloud server, a server or a box.

<!-- runtime:claude,openclaw -->
User request: $ARGUMENTS
<!-- /runtime -->

<!-- include: transport -->

<!-- include: operating-rules -->

<!-- include: errors -->

<!-- include: plans -->

<!-- include: code-mode -->

## Who can use cloud servers

- **Plan gate.** A cloud server is an add-on, sold on every plan, Free included: no Pro plan is needed. The entitlements feature `vps` is true on an active (or past-due) account that holds at least one cloud server slot from the VPS add-on, or has an admin grant. The plan alone is not enough: the add-on must be bought too, in the portal. `vps_create` answers `feature_required` (feature `vps`) otherwise.
- **Capacity.** The entitlements `limits` carry `vps` (servers), `vps_ram_gib`, `vps_vcpu` and `vps_disk_10gb`, each `used`/`max`. The last three count what each server uses **above the base shape**, so the base shape needs only a free server slot. `vps_bw_gb` is the account's outbound transfer this month against the included amount.
- **Roles.** `vps_catalog`, `vps_list`, `vps_get` and `vps_rdns` with `sub_action=get` work with any token role. Every other call needs **net-admin** (`insufficient_role` otherwise).

## Endpoints

- `vps_catalog`: what a server can be. Returns `regions[]` (`id` such as `mia1`, `name`, `available`), `images[]` (`id`, `name`, `arch`, `sha256`, `default`) and `pricing`: `base` (vCPUs, memory, disk, `monthly_usd`, what it includes), `increments` (monthly price per extra GiB of memory, per extra vCPU, per extra 10 GB of disk), `caps` (largest shape per server, disk step), `presets[]` (objects `{id, label, vcpus, memory_gib, disk_gb, monthly_usd, annual_usd}`, with `id` `s`, `m` or `l`), `annual_multiplier`, `currency`, `requires_pro` (false: any plan), `firewall_rules_per_server` (the firewall rule cap per server, by plan id). Read it live every time: never quote shapes or prices from memory.
- `vps_create` (net-admin): create a server. Params: `name` (required), `ssh_keys` (required), and optional `size` (`s`, `m` or `l`), `vcpus`, `memory_gib`, `disk_gb`, `site` (a region `id`, default `mia1`; `region` is accepted too), `image` (an image `id`, default Debian 13), `domain` (one of the account's domains from `list_domains`). Returns `vps_id`, `name`, `state` (`pending`), `region`, `host`, `public_ipv4`, `public_ipv6`, `public_ipv6_prefix`, `shape`, `monthly_usd`, `image`, `mesh_mode` (`mine`), `domain`, `fqdn`, `message`, and the server's `tunnel_token` (a credential: never print it).
- `vps_list`: the account's servers. Returns `count`, `servers[]` and `bandwidth_pool`. Each server has `vps_id`, `name`, `state`, `detail` (what is happening now), `progress`, `region`, `region_name`, `public_ipv4`, `public_ipv6`, `public_ipv6_prefix`, `size`, `vcpus`, `memory_mb`, `disk_gb`, `image`, `monthly_usd`, `fqdn`, `rdns_v4`, `rdns_v6`, `firewall_enabled`, `firewall_applied_at`, `firewall_rules_used`, `firewall_rules_max` (rules added to this server and its cap; `-1` is no cap), `mesh_mode`, `password_applied`, `keys_applied`, `bw_month_gb`, `throttled`, `ssh_command`, `created_at`, `started_at`, and its `tunnel_token`. Never print it raw: select fields with `jq`.
- `vps_get`: one server, as `vps_get=1&vps_id=<id>`. Returns `vps` (the same fields as one `vps_list` entry, `tunnel_token` included, plus `bandwidth_pool` nested inside it: read `.vps.bandwidth_pool`; `vps_list` has it at the top level). Poll it after `vps_create` until `state` is `running`, and after `vps_keys` or `vps_root_password` until `keys_applied` or `password_applied` turns true.
- `vps_power` (net-admin): `action` = `start`, `stop` or `restart`, plus `vps_id`. `stop` is a clean shutdown; the host forces it if the system does not stop in time. Returns the new `state` (`starting`, `stopping` or `restarting`), which settles on the next host report.
- `vps_mesh` (net-admin): who on doxx.net reaches the server, ahead of the firewall rules. `mode` = `mine` (the default: every connection from the user's own devices, the devices of guests seated on the user's plan, the user's dedicated addresses and the user's other cloud servers), `full` (every doxx.net address: all tunnels, dedicated addresses and cloud servers of every doxx.net user) or `off` (only the firewall rules apply), plus `vps_id`. Returns `mesh_mode`, `mesh_prefixes` (the source addresses now allowed). The change reaches the host within a minute. Always pass `mode`: the old `enabled=1` form means `full`, not `mine`.
- `vps_dns` (net-admin): name the server `<name>.<domain>` under one of the account's domains: A and AAAA records plus matching reverse DNS. Params: `vps_id`, `domain` (from `list_domains`; empty removes the records; a new domain moves them). Returns `fqdn` and `records`.
- `vps_rdns`: reverse DNS (PTR) for the server's addresses. `sub_action` = `get` (any role; returns `v4` and `v6`, each with `address` and `ptr`), `set` (net-admin; `family` = `v4` or `v6`, default `v4`, and `name` = a fully qualified host name) or `clear` (net-admin; `family`), plus `vps_id`. IPv4 reverse DNS also depends on the carrier's delegation for that block.
- `vps_root_password` (net-admin): the root password, for the console and recovery only (SSH is key-only). `sub_action` = `get` (default) or `reset`, plus `vps_id`. Both return `password` and `applied`. After `reset`, the host sets the new password within a minute (`password_applied` on `vps_get`). Every read is recorded in the server's audit log. Handle the answer as described in "Root password" below.
- `vps_keys` (net-admin): replace root's SSH keys. `sub_action=set`, `keys` (same format as `ssh_keys`), plus `vps_id`. The new list **replaces** the old one; doxx.net does not keep it, so there is no way to read it back. Returns `count` and `applied` (`keys_applied` on `vps_get` turns true once the host writes them; a stopped server gets them when it starts).
- `vps_delete` (net-admin): destroy a server. Params: `vps_id`, `confirm` (the server's name, exactly). Irreversible. Returns `state` (`destroying`) and `message`.
- `list_domains`: the account's domains, for `domain` on `vps_create` and `vps_dns`.
- `firewall_rule_add`: open a port on the server to the internet, with the server's own `tunnel_token` (see "Connect and open ports").

## Calls that show only safe fields

Every `vps_list` and `vps_get` answer holds `tunnel_token` values, and `vps_create` returns one. Run them through `jq` as below and never print the raw answer.

**List the servers:**

```
printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "vps_list=1" --data-urlencode "token@-" | jq 'if .status == "success" then {count, servers: [.servers[] | {vps_id, name, state, detail, region_name, public_ipv4, public_ipv6, fqdn, vcpus, memory_mb, disk_gb, monthly_usd, mesh_mode, ssh_command}]} else del(.tunnel_token) end'
```

**One server by name, in the shell.** Server names are unique in an account. This sets `$id` (the `vps_id`) and `$tt` (the server's `tunnel_token`) without printing either token. Put it before the call that needs them, with `NAME` replaced:

```
l=$(printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "vps_list=1" --data-urlencode "token@-")
id=$(printf %s "$l" | jq -r --arg n "NAME" '[.servers[]? | select(.name == $n)] | if length == 1 then .[0].vps_id else empty end')
tt=$(printf %s "$l" | jq -r --arg n "NAME" '[.servers[]? | select(.name == $n)] | if length == 1 then .[0].tunnel_token else empty end')
[ "$(printf %s "$l" | jq -r .status)" = success ] || { printf %s "$l" | jq -r '"error: " + (.message // "no message")'; exit 1; }
[ -n "$id" ] || { echo "no server named NAME"; exit 1; }
```

A `vps_id` is not a secret: you may show it.

## Create a server

1. **Check the entitlements** ("Plans and entitlements"): `features.vps` and the four `vps*` limits. If `vps` is false, say that a cloud server needs the VPS add-on, which is sold on every plan (Free included, no Pro needed), give the plan page, and stop.
2. **Read the catalog** (`vps_catalog`). Show the regions that are `available`, the presets with their live `monthly_usd`, and the base, increments and caps if the user wants a custom shape. For a custom shape, the monthly price is the base price plus each increment times the units above the base: compute it from the catalog numbers, never from memory.
3. **Collect the request.**
   - `name`: a DNS label, 1 to 63 characters, lowercase letters, digits and hyphens, not starting or ending with a hyphen, unique among the user's servers. It is also the machine's host name.
   - Shape: `size=s|m|l`, or `vcpus`, `memory_gib`, `disk_gb` (disk in steps from the catalog). A preset plus one explicit value overrides only that value.
   - Region: a `site` that is `available` in the catalog.
   - `ssh_keys`: one or more OpenSSH **public** key lines (a JSON array or one key per line). Login is key-only, so at least one key is required. If the user has a key on this machine, offer one of `~/.ssh/*.pub` and show its fingerprint (`ssh-keygen -lf ~/.ssh/id_ed25519.pub`). Only ever send a `.pub` file: never read or send a private key.
   - Optional `domain` (from `list_domains`) to name the server `<name>.<domain>` at once.
4. **Confirm before you create.** Repeat the name, region, shape (vCPUs, memory, disk), image and the monthly cost from the catalog, and say that it uses a server slot and any extra memory, vCPUs and disk from the user's VPS add-on. Create only after a clear yes.
5. **Create** (with `NAME`, the size or shape, the site and the key file replaced). The `jq` step drops `tunnel_token`:

   ```
   printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "vps_create=1&name=NAME&size=s&site=mia1" --data-urlencode "ssh_keys@$HOME/.ssh/id_ed25519.pub" --data-urlencode "token@-" | jq 'del(.tunnel_token)'
   ```

6. **Wait for it.** A new server takes about a minute.

   **Fast path:** `bash <skill dir>/scripts/vps-wait.sh NAME` finds the server by name (or `vps_id`), polls `vps_get` every 10 seconds and prints each state change. It ends when the state is `running` or `stopped` (exit 0), `error` or `suspended` (exit 1, with the detail), or after 100 seconds (exit 3, last state printed). On exit 3, run it again while the state still moves, and stop after about five minutes in total: then report the last state to the user. It never prints the `tunnel_token`. Use it after `vps_power` too.
<!-- runtime:claude -->
   The default fits the Bash tool's 2-minute limit. With the tool timeout raised (for example 330000 ms), you may pass `--timeout 300` instead.
<!-- /runtime -->

   Without the script, poll `vps_get` every 10 seconds; this loop runs for about 90 seconds (under the default tool timeout) and prints only the state. Run it again if the state is still moving, and stop after about five minutes in total: then report the last `state` and `detail` to the user instead of polling forever.

   ```
   for i in 1 2 3 4 5 6 7 8 9; do
     s=$(printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "vps_get=1&vps_id=VPS_ID" --data-urlencode "token@-" | jq -r 'if .status == "success" then "\(.vps.state) \(.vps.detail // "")" else "error: \(.message)" end')
     echo "$s"; case "$s" in running*|stopped*|error*|suspended*) break;; esac; sleep 10
   done
   ```

   States: `pending`, `provisioning`, `starting`, `booting`, `running`, `stopping`, `stopped`, `restarting`, `suspended`, `destroying`, `error`.
7. **Report:** the name, region, public IPv4 and IPv6, `fqdn` if set, the monthly cost, and how to connect (below). Show the API's `message` as given.

## Connect and open ports

- **SSH:** `ssh root@<public_ipv4>` (the server's `ssh_command`), with the private key that matches a key the server was given. It works at once from the user's own devices while they are on a doxx.net tunnel (mesh mode `mine`).
- **From the internet** the server answers only ping until ports are opened. A new server gets only ICMP rules: SSH and everything else from the internet need a rule. Open a port with `firewall_rule_add` on the server's `tunnel_token` and its public address as `dst_ip` (with `$tt` from "One server by name"):

  ```
  printf 'url=https://config.doxx.net/v1/\ndata-urlencode=token=%s\ndata-urlencode=tunnel_token=%s\n' "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" "$tt" | awk -v n=3 '{s = ""; for (i = 1; i <= length($0); i++) {c = substr($0, i, 1); s = s (c == "\\" || c == "\"" ? "\\" : "") c}; k = index(s, "="); o = o substr(s, 1, k - 1) " = \"" substr(s, k + 1) "\"\n"} END {if (NR == n) printf "%s", o}' | curl -s -K - -X POST -d "firewall_rule_add=1&protocol=TCP&src_ip=0.0.0.0/0&dst_ip=PUBLIC_IPV4&dst_port=443"
  ```

  Repeat with `src_ip=::/0` and the `public_ipv6` for IPv6. Confirm each opening with the user first, and prefer the smallest set of ports. Rules reach the host within a minute (`firewall_applied_at` on `vps_get`). Rules on a server's own `tunnel_token` work on every plan and do not count against the device firewall rule quota. Each server has its own cap instead: `firewall_rules_used` and `firewall_rules_max` on `vps_list` / `vps_get` (the two default ICMP rules do not count). At the cap the call answers 409 `vps_firewall_limit`: show `message` and `fix`, and offer to remove a rule the user no longer needs; a higher cap comes with a higher plan (`upgrade_url`). Never retry in a loop. Listing and deleting rules: the `manage-firewall` skill, with the same `tunnel_token`.
- **Mesh is not the internet.** A service that answers from the user's laptop over the mesh can still be closed to the internet. Test from a device that is not on a doxx.net tunnel.

## Confirm before these changes

Ask, wait for a clear yes, and only then call:

- **Create:** name, region, shape, image and the monthly cost from the catalog.
- **Stop or restart:** the server and everything on it goes offline (a restart for a short time, a stop until it is started again).
- **Mesh `full`:** every doxx.net device and cloud server, including those of other doxx.net users, then reaches every port of the server over the mesh, ahead of the firewall rules. Recommend `mine` (the user's own devices, guests seated on their plan, their dedicated addresses and their other servers) unless the user has a reason.
- **Mesh `off`:** the user's own devices then reach only the ports that firewall rules open, which can cut off their own SSH.
- **Replace SSH keys** (`vps_keys`): the old keys stop working. Make sure the new list holds a key the user still has.
- **Change or remove the DNS name** (`vps_dns` with an empty or different `domain`): the public A, AAAA and reverse DNS records for the old name are removed or moved, so the old name stops resolving.
- **Clear reverse DNS** (`vps_rdns` with `sub_action=clear`): the custom PTR name for that address is removed.
- **Reset the root password:** the old password stops working once the host applies the new one.
- **Delete:** see below.

## Delete a server

`vps_delete` is permanent: the host removes the machine and its disk; its firewall rules, DNS name records, reverse DNS records and device entry go; its addresses are held back for 30 days before they return to the pool. Server slot and capacity in the add-on are freed when the host finishes.

1. Find the server by name (`vps_list`) and show its name, region, public addresses and `fqdn`.
2. Say what will be lost and that it cannot be undone. Ask the user to **type the server's exact name** to confirm. A "yes" is not enough.
3. Repeat the name back and call `vps_delete` with `confirm` set to that exact name. If what the user typed does not match the name, do not call it: ask again.

## Root password

The password is a secret. **Do not print it into the conversation.** Save it to a private file and give the user the path:

```
d=$(mktemp -d "${TMPDIR:-/tmp}/doxx-vps.XXXXXX") || exit 1; chmod 700 "$d"; echo "dir: $d"
r=$(printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "vps_root_password=1&vps_id=VPS_ID&sub_action=get" --data-urlencode "token@-")
if [ "$(printf %s "$r" | jq -r .status)" = success ]; then
  (umask 077 && printf %s "$r" | jq -r .password > "$d/root-password")
  printf %s "$r" | jq -r '"saved, applied on the server: \(.applied)"'
else
  printf %s "$r" | jq -r '"error: " + (.message // "no message")'
  rmdir "$d"
fi
```

For a reset (after confirmation), use `sub_action=reset` in the same command. Below, the printed directory is `DIR`. Tell the user the file is `DIR/root-password` (mode 600) and ask them to move it into their password manager. Then offer to delete it: `rm -f DIR/root-password && rmdir DIR`. Never `cat` the file yourself unless the user explicitly asks to see the password here, and then say first that it stays in the conversation history. A server created before Nov 9 2026 has no password on file: `get` answers 404, and a `reset` sets one.

## Name, DNS and reverse DNS

- `vps_dns` with `domain` is the short path: it writes A, AAAA and both reverse DNS records for `<name>.<domain>` in one call. For other host names on the server (the apex, `www`), use the DNS record endpoints of the `manage-domains` skill.
- `vps_rdns` sets a custom reverse DNS name (for example for a mail server). The records belong to the user for the life of the server.

## Cloud server stats

CPU, memory, disk and network gauges come from the Stats API at `/api/stats/vps` (see the `network-stats` skill for the Stats API). Its answer is keyed by `tunnel_token`, so map it to server names and never print it raw. This prints the newest reading per server:

```
s=$(printf 'header=X-Auth-Token: %s\nurl=%s\n' "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" "https://secure-wss.doxx.net/api/stats/vps?latest_only=1" | awk -v n=2 '{s = ""; for (i = 1; i <= length($0); i++) {c = substr($0, i, 1); s = s (c == "\\" || c == "\"" ? "\\" : "") c}; k = index(s, "="); o = o substr(s, 1, k - 1) " = \"" substr(s, k + 1) "\"\n"} END {if (NR == n) printf "%s", o}' | curl -s -K - -X POST)
printf %s "$s" | jq -e . >/dev/null 2>&1 || { echo "stats error: $s"; exit 1; }
l=$(printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "vps_list=1" --data-urlencode "token@-")
printf '%s\n%s' "$l" "$s" | jq -s '(.[0].servers // [] | map({key: .vps_id, value: .name}) | from_entries) as $n | [(.[1].latest // {})[] | {server: ($n[.vps_id] // "unknown server"), age_s, metrics}]'
```

`metrics`: `cpu` (percent of the server's vCPUs), `mem_used` and `mem_total` (MiB), `disk_used` and `disk_total` (GB), `in` and `out` (Mbit/s), `rd` and `wr` (MB/s). A stopped server sends nothing, so it has no entry: that is not an error. For history, use `start` and `end` (RFC3339) instead of `latest_only=1`.

## Billing and suspension

- If the plan lapses, or the user lowers the VPS add-on below what the servers use, the newest servers are **suspended** first (stopped, kept with their disks) until the rest fit.
- A suspended server is **destroyed after 14 days**. If the account pays again in time, suspended servers start again, oldest first, as far as the add-on allows. Power actions are refused while a server is suspended. `device_list_unified` shows the deadline in the server's `services.vps.detail.expires_at`.
- Outbound internet transfer has a monthly allowance shared by the account's servers (`bandwidth_pool` on `vps_list`, `vps_bw_gb` in the entitlements). Show the API's own figures; never quote them from memory.

## Errors you will meet here

- Error `vps_limit` (409): the add-on lacks a server slot, memory, cores or storage for this shape. Show `message`, `component`, `available`, `needed`, `monthly_usd` and `fix`. `upgrade_url` is a path on the portal: show it as `https://app.doxx.net` plus that path. Offer a smaller shape if one fits. Never buy or add capacity for the user.
- Error `feature_required` (403, feature `vps`): no VPS add-on on the account (any plan can buy it).
- Error `vps_firewall_limit` (409) on `firewall_rule_add`: the server holds its cap of rules. Show `used`, `max` and `fix`; `upgrade_url` is a portal path, shown as `https://app.doxx.net` plus that path.
- 400: a bad name, shape (outside the caps, or disk not in steps), image, or SSH key. The `message` names the field.
- 403 "Domain not found or not yours": pick a domain from `list_domains`.
- 409 "You already have a server with that name": choose another name.
- 409 "No capacity in <region> right now": offer another `available` region or a smaller shape.
- 503 "VPS hosts are not reachable right now" or "Address allocation failed": try once more after a short wait, then report it.
- 409 on `vps_power`: the server is `pending`, `provisioning`, `destroying` or `suspended`. Wait and check `vps_get`.
- 409 "Already being deleted" on `vps_delete`; 400 "confirm must be the server's name": the name did not match.
- 404 "Server not found": wrong `vps_id`, or the server is gone. List again.

## Guidelines

- Check the entitlements before planning a server, and read prices only from `vps_catalog` (or the `monthly_usd` the API returns).
- Refer to servers by name. Never print a `tunnel_token`, a root password or a raw `vps_list`, `vps_get` or `vps_create` answer.
- One write at a time; check `status` before the next call.
- A cloud server also shows in the device list (`device_type: "vps"`), but device endpoints cannot rename or delete it: only `vps_delete` removes it.

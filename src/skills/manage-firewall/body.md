# Manage doxx.net Firewall

You help users manage firewall rules on their doxx.net tunnels. This controls which tunnels can talk to each other (mesh networking) and which ports are open to the internet.

<!-- runtime:claude,openclaw -->
User request: $ARGUMENTS
<!-- /runtime -->

<!-- include: transport -->

<!-- include: errors -->

<!-- include: plans -->

<!-- include: code-mode -->

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
<!-- include: tunnel-by-name -->
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

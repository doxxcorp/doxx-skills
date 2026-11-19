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

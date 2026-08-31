# Changelog

## 1.1.0

Sync to config.doxx.net API 1.1.0 (doxxGateway release).

- Added `manage-agents` skill (Claude, OpenClaw, Codex): create/list/delete AI-agent chat principals for the doxxGateway (`github.com/doxxcorp/gateway`), including the owner-only + double-opt-in trust model and legacy-bot cleanup
- Documented the `agents` endpoints (`create_agent`, `list_agents`, `delete_agent`) and `bots` deprecation (`create_bot` -> 410, `list_bots`/`delete_bot` retained) in `api/reference.md`
- Added token-tunnel scoping (`add_token_tunnel`, `remove_token_tunnel`) to `manage-tokens` and the reference, fulfilling the skill's existing "scope tokens to specific tunnels" description
- Removed `subscription_status` and `merge_account` (dropped from the Config API in 1.1.0); subscription now redirects to the a0x13 portal
- Corrected `update_profile`/`get_profile` params (`email`/`phone`/`notifications_enabled`) and the `create_token` default role (`admin`)
- Added an `ssh_to_server_behind_nat` least-privilege mesh pattern to `manage-firewall`
- Bumped plugin/marketplace version to 1.1.0

## 1.0.0

Public release. OpenClaw support, complete API reference, CI validation.

- Added OpenClaw skill ports for all 11 skills
- Added CONTRIBUTING.md, issue templates, PR template
- Completed API reference with Devices, IP Addresses, Saved Profiles, and Account endpoints
- Updated install instructions for public marketplace
- Narrowed sudo permissions to `sudo wg-quick *` only
- Full CI validation for both Claude and OpenClaw skills

## 0.4.0

- Added manage-devices, manage-addresses, manage-account skills
- Added evals for all 11 skills
- Added API consistency checks to CI
- Synced marketplace.json with plugin.json

## 0.3.0

- Added network-stats, network-status skills
- Added Stats API documentation

## 0.2.0

- Added manage-domains, manage-firewall, manage-dns-blocking skills
- Added DNS, Firewall, and Domain API documentation

## 0.1.0

Initial release.

- doxxnet (general-purpose skill)
- network-wizard (guided setup)
- manage-tunnels (tunnel CRUD + WireGuard configs)
- API reference with core endpoints

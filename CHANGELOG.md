# Changelog

## 1.2.0

Renovation against the current Config API (live manifest 1.1.0 as of 2026-11-24) and Stats API.

**Build and tooling**

- One source for all three runtimes: skills live in `src/skills/<name>/` (body, per-runtime frontmatter, evals, optional scripts) with shared partials in `src/partials/`, and `make build` (`scripts/build.sh`) generates `claude/`, `openclaw/` and `codex/`. `make build-check` fails on stale generated files. The build stops on malformed include or runtime markers (including CRLF), frontmatter without a trailing newline, and an incomplete stage, and never wipes a runtime tree it cannot fully replace.
- Version single-sourced in `VERSION`: the build stamps it into the OpenClaw frontmatter, and `make validate` checks it against plugin.json, marketplace.json, the ClawHub bundle and this changelog.
- `make api-drift` (`scripts/api-drift.sh`): compares the live Config API manifest with `api/reference.md` and exits 1 on drift; `--manifest FILE` (or `make api-drift MANIFEST=FILE`) runs offline. Intentional extras are listed in `api/drift-allowlist.txt`.
- `make validate` also checks that every script a skill names ships with it, forbids em dashes in sources and docs, forbids "VPN" outside quoted user wording, and fails if public text names an endpoint outside the public manifest. `make check` runs build-check, clawhub-check and validate.
- CI (`.github/workflows/check.yml`) runs `make check` and `make test` on Ubuntu and macOS for every pull request and push to main. Scripts are committed executable, `make validate` checks the mode in the git index and runs `shellcheck -x` on every shell script, and in CI a missing shellcheck, jq or curl is a failure instead of a skip.
- ClawHub bundle ships the Code Mode scripts (`scripts/`, `lib/doxx.sh`), and its build fails if a reference file names a script that is not in the bundle.

**Token and transport**

- Token sources, first found wins (only the first non-empty line of a token file is read): `DOXX_TOKEN`, `~/.config/doxx/token`, then the legacy `DOXXNET_TOKEN` and `~/.config/doxxnet/token`. OpenClaw `requires.env` and `primaryEnv` are now `DOXX_TOKEN`.
- Migration: set `DOXX_TOKEN`, or write the token to `~/.config/doxx/token` with mode 0600. OpenClaw users must set `DOXX_TOKEN`, because OpenClaw gating now requires it: a token only in `DOXXNET_TOKEN` or the old file still works at run time, but OpenClaw may stop offering the skills. The old env var and file are still read.
- The token is piped to curl on stdin, so it is not in the command line or the process list. Secret params (`tunnel_token`, `target_token`) and the Stats header travel the same way, as a curl config read with `-K -` (the URL included; a small `awk` filter escapes each value and writes nothing when a value holds a line break, so a value can never add a curl option of its own); `lib/doxx.sh` sends every param that way, and `make test` checks every curl command line through a `curl` shim, with a canary that must trip the check. `tunnel_token` values and private keys are never printed: answers such as `list_tunnels` are filtered with `jq`.
- curl is the main path; if a doxx MCP server is configured, its tools are used instead. Shared partials for calling the API, operating rules, errors, plans and WireGuard QR delivery replace per-skill setup text.
- Stats API: params go in the query string with header auth (`start`/`end` for bandwidth, `last` for alerts); tunnel tokens are mapped to tunnel names.

**Skills**

- New `manage-vps` skill for doxx.net cloud servers: catalog with live prices, create, power, mesh modes, DNS and reverse DNS, root password (to a private 0600 file), SSH keys, delete with the exact name.
- Code Mode scripts with a shared `lib/doxx.sh`: `status-summary.sh` (network-status), `firewall-audit.sh` (manage-firewall), `snapshot.sh` (doxxnet), `vps-wait.sh` (manage-vps). Offline tests with a fake API (`make test`) assert that no token or private key leaks.
- New endpoints across skills: `device_status`, `device_logout` (this machine only), `device_service_state` (read only, through `device_list_unified`), `dns_blocking_pause`, `update_agent` and webhook agents, `role=device` tokens bound to a tunnel or agent, `network_info`, `mesh_public_pools`, new `update_tunnel`, `assign_address` and `lease_public_ipv4` params, `purpose=port_forward`, `domain_limit`.
- Removed internal endpoints: the skills call only endpoints in the public manifest. Recovery codes are managed in the portal; WireGuard QR codes are made locally with `qrencode`.
- Saved profiles: `load_profile`'s 409 `profile_in_use` is in the error table (show the message, name the tunnel that holds the profile, never print `in_use_tunnel_token`, never act on `release_action`), and `list_saved_profiles` documents `in_use_by_address`. The reference also covers the public `clients` group (`current_build`, `macos_releases`), which the skills do not use.
- Plans: Free, Essentials (API slug `basic`) and Pro; Pro+ is legacy. No seat counts, limits or prices in the skills: they read the live entitlements and the public price list, and explain gate errors (`feature_required`, limits, `upgrade_url`). Portal links point to app.doxx.net.
- Frontmatter descriptions list the new capabilities.
- Claude Code plugin: `plugin.json` lists all 14 skills under `skills` (it listed only `doxxnet` and `network-wizard` under `commands`), so the specialist skills `doxxnet` hands off to are installed too. `make validate` checks that every skill in `src/skills` is listed.
- Commands that need a tunnel's token find it by tunnel name inside the shell (`$tt`), so the token is never typed into a command. Duplicate tunnel names in Stats answers get a suffix (`alpha (2)`) instead of being merged.
- Claude `allowed-tools` narrowed: no `cat` or `Read`, and `wg-quick` only as `sudo wg-quick up doxx` / `down doxx`. OpenClaw `requires.bins` adds `jq` where secret-bearing answers are filtered and drops `wg-quick` (optional). Without `jq`, skills do not make calls whose answers carry secrets.

**API reference**

- `api/reference.md` rewritten against the server code: all 102 manifest endpoints, roles, gates and side effects, the Stats API, and a "Known manifest errors" section for the few places where the manifest still disagrees with the handlers. `update_profile` is documented as a partial update. `api/README.md` covers the protocol, token, regional endpoints and plans without hardcoded numbers.

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

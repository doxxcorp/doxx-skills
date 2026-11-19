# doxx-skills for OpenClaw

AI agent skills for managing [doxx.net](https://doxx.net) private networks via [OpenClaw](https://openclaw.org).

These files are generated from `src/` by `make build`: edit the source, not this tree (see [CONTRIBUTING.md](../CONTRIBUTING.md)).

## Install

```bash
openclaw skills install @doxxcorp/doxxnet
```

Or from a local clone:

```bash
openclaw skills install ./openclaw/skills/doxxnet
```

The registry package (`@doxxcorp/doxxnet`) is one folder: the `doxxnet` skill with every other skill as a reference file, plus the Code Mode scripts.

## Setup

Requirements: `curl` 7.55 or later and `jq` 1.6 or later. Some skills also use `openssl` or `dig`; each skill declares its binaries in its `metadata.openclaw.requires.bins`. The WireGuard tools (`wg-quick`) are optional: they are needed only to bring a tunnel up on this machine.

The skills read the token from the first of these that is set:

1. `DOXX_TOKEN` environment variable (preferred):

   ```bash
   read -rs DOXX_TOKEN && export DOXX_TOKEN
   ```

   Paste the token at the silent prompt and press Enter. `read -rs` keeps the token off the screen and out of your shell history, which a plain `export DOXX_TOKEN=...` line would not.

2. `~/.config/doxx/token`, mode 0600 (paste the token at the silent prompt, then press Enter):

   ```bash
   mkdir -p ~/.config/doxx && (umask 077 && read -rs t && printf %s "$t" > ~/.config/doxx/token)
   ```

3. Legacy names, still read: the `DOXXNET_TOKEN` variable and `~/.config/doxxnet/token`.

The token is piped into `curl` on stdin, so the shell expands it on this machine: it is not in the command line and never in the messages sent to the LLM. To keep the token across sessions, save it in the token file (option 2) rather than writing it into your shell profile.

Create a token in the portal at [app.doxx.net](https://app.doxx.net) (accounts are human-only, proof-of-work gated). For an agent, a `net-admin` token with a 7 to 30 day expiry is the safest choice.

OpenClaw gating: every skill declares `requires.env: [DOXX_TOKEN]` and `primaryEnv: DOXX_TOKEN`, so OpenClaw loads the skills when `DOXX_TOKEN` is set in the environment or given as the skill's `apiKey` in the OpenClaw config. A token kept only in a file, or only in the legacy `DOXXNET_TOKEN`, still works at run time, but OpenClaw may not offer the skills until `DOXX_TOKEN` is provided.

## Skills

| Skill | What it does |
|-------|-------------|
| **doxxnet** | General-purpose: every area below, routed by what you ask |
| **network-wizard** | Guided setup: auth, servers, tunnels, mesh networking, domains, DNS blocking, client install |
| **manage-tunnels** | Create, update, move and delete tunnels; WireGuard configs and QR codes |
| **manage-devices** | List, rename, change icons, check status, log this machine out, delete devices |
| **manage-addresses** | Assign, release and rotate IPs, lease dedicated IPv4, saved connection profiles |
| **manage-account** | Recovery email and phone, notifications, account deletion; recovery codes in the portal |
| **manage-tokens** | Create, revoke and update tokens, device tokens, geo and IP fences, tunnel scoping |
| **manage-agents** | AI-agent chat principals for the doxxGateway, webhook agents, legacy bot cleanup |
| **manage-domains** | Register and import domains, DNS records, TLS certificates |
| **manage-firewall** | Open ports, port forwards, link tunnels for mesh networking |
| **manage-dns-blocking** | Blocklists, allow and block rules, pause blocking, Secure DNS, blocklist stats |
| **manage-vps** | Cloud servers (VPS): catalog and live prices, create, power, mesh access, DNS, root password, SSH keys, delete |
| **network-status** | Live status: tunnels, devices, bandwidth, security alerts, this machine's public address |
| **network-stats** | Detailed bandwidth, security alerts, threat categories, peak throughput |

## Code Mode scripts

`doxxnet`, `network-status`, `manage-firewall` and `manage-vps` ship bash scripts in their `scripts/` directory (with a shared `lib/doxx.sh`) that make many reads in one run and print only a summary. They need `bash`, `curl` and `jq`, are read-only, and print the endpoints they called.

## doxx MCP tools

The skills use `curl` by default. If a doxx MCP server is configured for the agent, the skills use its tools automatically (tool names match the API endpoint names, and the server adds the token).

## How It Works

Skills call the doxx.net API directly via `curl`. No intermediate servers, no daemons.

## API Reference

For use outside OpenClaw, see [api/reference.md](../api/reference.md) for the full doxx.net API with curl examples.

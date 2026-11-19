# doxx.net Codex Agent Skills

doxx.net skills for [OpenAI Codex CLI](https://github.com/openai/codex). Each skill is an `AGENTS.md` instruction file that Codex loads automatically.

These files are generated from `src/` by `make build`: edit the source, not this tree (see [CONTRIBUTING.md](../CONTRIBUTING.md)).

## Requirements

- A doxx.net account and auth token: create them in the portal at [app.doxx.net](https://app.doxx.net)
- `curl` 7.55 or later and `jq` 1.6 or later

## Token

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

## Usage

### Interactive

Run Codex from a skill directory: it auto-loads `AGENTS.md`:

```bash
cd codex/skills/doxxnet
codex
```

Then type your request naturally:

```
Show me my tunnels and bandwidth usage
```

### Non-interactive

Use `codex exec` to pass a request directly:

```bash
cd codex/skills/doxxnet
codex exec "Show me my tunnels"
```

Or from a focused skill directory:

```bash
cd codex/skills/manage-tunnels
codex exec "Create a tunnel in New York named laptop"
```

## Skills

Each skill directory is self-contained: its `AGENTS.md` plus any `scripts/` and `lib/` it uses. Codex loads the `AGENTS.md` of the directory it starts in, not the ones in sibling skill directories. When `doxxnet` hands a request to a specialist skill (for example "see `manage-vps`"), that skill's instructions are not loaded: to use them, start Codex from that skill's directory (`cd codex/skills/manage-vps && codex`).


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

## Authentication

doxx.net is anonymous by design: no usernames, no passwords, no email. Your auth token IS your identity.

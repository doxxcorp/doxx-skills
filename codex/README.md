# doxx.net Codex Agent Skills

doxx.net skills for [OpenAI Codex CLI](https://github.com/openai/codex). Each skill is an `AGENTS.md` instruction file that Codex loads automatically.

## Requirements

- A doxx.net account: create one at [a0x13.doxx.net](https://a0x13.doxx.net)
- Your doxx.net auth token set as an environment variable:

```bash
export DOXXNET_TOKEN=your-token
```

Add this to your shell profile (`~/.zshrc`, `~/.bashrc`) to persist across sessions.

## Usage

### Interactive

Run Codex from a skill directory: it auto-loads `AGENTS.md`:

```bash
cd agents/codex/skills/doxxnet
codex
```

Then type your request naturally:

```
Show me my tunnels and bandwidth usage
```

### Non-interactive

Use `codex exec` to pass a request directly:

```bash
DOXXNET_TOKEN=your-token codex exec "Show me my tunnels"
```

Or with the skill directory for full context:

```bash
cd agents/codex/skills/manage-tunnels
codex exec "Create a tunnel in New York named laptop"
```

## Skills

| Skill | What it does |
|-------|-------------|
| **doxxnet** | General-purpose: tunnels, firewall, domains, DNS blocking, stats |
| **network-wizard** | Guided full setup: auth, servers, tunnels, mesh, domains, DNS blocking, client install |
| **manage-tunnels** | Create, update, delete tunnels and get WireGuard configs |
| **manage-devices** | List, rename, change icons, and delete devices |
| **manage-addresses** | Assign, release, rotate IPs, lease dedicated IPv4, manage profiles |
| **manage-account** | Recovery settings, notifications, recovery codes, subscription status |
| **manage-domains** | Register domains, manage DNS records, sign TLS certificates |
| **manage-firewall** | Open ports, link tunnels, mesh networking rules |
| **manage-dns-blocking** | Enable ad/tracker blocking, manage whitelists/blacklists |
| **network-status** | Bandwidth stats, connection tracking, security alerts |
| **network-stats** | Detailed bandwidth, security alerts, threat categories, peak throughput |

## Authentication

doxx.net is anonymous by design: no usernames, no passwords, no email. Your auth token IS your identity. `DOXXNET_TOKEN` is used directly in all API calls.

If you don't have a token, create an account at [a0x13.doxx.net](https://a0x13.doxx.net) (human-only, proof-of-work gated).

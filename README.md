# doxx-skills

AI agent skills for setting up and managing [doxx.net](https://doxx.net) private networks through natural language.

## Install

Add the marketplace and install the plugin from within Claude Code:

```
/plugin marketplace add doxxcorp/doxx-skills
/plugin install doxx
```

Then use any skill as a slash command:

```
/doxx:network-wizard
```

## What's Inside

### Claude Code Plugin (`claude/`)

Interactive skills that let Claude set up and manage your doxx.net private network:

| Skill | What it does |
|-------|-------------|
| **network-wizard** | Full guided setup: auth, servers, tunnels, mesh networking, domains, DNS blocking, client install |
| **manage-tunnels** | Add/remove/move devices, get WireGuard configs |
| **manage-domains** | Register domains, manage DNS records, sign TLS certificates |
| **manage-firewall** | Open ports, link tunnels, mesh networking rules |
| **manage-dns-blocking** | Enable ad/tracker blocking, manage whitelists/blacklists |
| **network-status** | Bandwidth stats, connection tracking, security alerts |

### Shared Resources (`shared/`)

Agent-agnostic workflows and guides that any AI agent can use:

- **workflows/** — Step-by-step procedures for common tasks
- **client-guides/** — Platform-specific WireGuard installation (macOS, iOS, Android)

### API Reference (`api/`)

Condensed doxx.net API reference optimized for agent consumption.

## Requirements

- A doxx.net account (create one at [a0x13.doxx.net](https://a0x13.doxx.net))
- [Claude Code](https://claude.ai/claude-code) (for the Claude plugin)
- `curl`, `jq` (for API calls)
- `wg-quick` / WireGuard (for VPN connection)

## How It Works

doxx.net is anonymous by design. There are no usernames, passwords, or emails. Your auth token **is** your identity.

1. You create an account at [a0x13.doxx.net](https://a0x13.doxx.net) (human-only, proof-of-work gated)
2. You give your auth token to the skill
3. The skill makes API calls on your behalf to set up your private network
4. WireGuard configs are generated and installed on your devices

No secrets are stored in this repo. Tokens are always provided by you at runtime.

## License

MIT

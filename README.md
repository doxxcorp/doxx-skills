<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/logo-light.png">
  <source media="(prefers-color-scheme: light)" srcset="assets/logo-dark.png">
  <img alt="doxx.net" src="assets/logo-dark.png" width="180">
</picture>

# doxx-skills

AI agent skills for setting up and managing [doxx.net](https://doxx.net) private networks through natural language.

## Getting Started

### Claude Code (CLI)

Run these commands inside [Claude Code](https://code.claude.com/):

```
/plugin marketplace add doxxcorp/doxx-skills
/plugin install doxxnet
```

The plugin is fetched directly from GitHub, no cloning needed. Once installed, use any skill as a slash command:

```
/doxxnet:network-wizard
```

### Claude Code for Cursor / VS Code

1. Open Claude Code in the editor
2. Add the marketplace: `/plugin marketplace add doxxcorp/doxx-skills`
3. Open the plugin manager: `/plugins`
4. Switch to the **Plugins** tab: **doxxnet** will appear under available plugins
5. Click **Install** and choose your scope (user, project, or local)

Once installed, type `/doxxnet:network-wizard` in the chat to get started.

### Other Agents

Any AI agent with shell access can use the shared resources in this repo directly:

- **[api/reference.md](api/reference.md)**: Condensed doxx.net API reference optimized for agent consumption
- **[shared/workflows/](shared/workflows/)**: Step-by-step procedures for common tasks (private network setup, tunnels, domains, client install)
- **[shared/client-guides/](shared/client-guides/)**: Platform-specific WireGuard installation (macOS, iOS, Android)

Point your agent at the relevant file and provide your doxx.net auth token at runtime.

## What's Inside

### Claude Code Plugin (`claude/`)

Interactive skills with guided workflows:

| Skill | What it does |
|-------|-------------|
| **network-wizard** | Full guided setup: auth, servers, tunnels, mesh networking, domains, DNS blocking, client install |
| **manage-tunnels** | Add/remove/move devices, get WireGuard configs |
| **manage-domains** | Register domains, manage DNS records, sign TLS certificates |
| **manage-firewall** | Open ports, link tunnels, mesh networking rules |
| **manage-dns-blocking** | Enable ad/tracker blocking, manage whitelists/blacklists |
| **network-status** | Bandwidth stats, connection tracking, security alerts |

### Shared Resources (`shared/`, `api/`)

Agent-agnostic workflows, guides, and API reference that work with any AI agent or can be followed manually:

- **api/reference.md**: Every doxx.net API endpoint with curl examples
- **shared/workflows/**: Step-by-step procedures for common tasks
- **shared/client-guides/**: Platform-specific WireGuard installation (macOS, iOS, Android)

## Requirements

- A doxx.net account (create one at [a0x13.doxx.net](https://a0x13.doxx.net))
- doxx.net client (macOS, iOS, Android) or [WireGuard](https://www.wireguard.com/install/)

## How It Works

doxx.net is anonymous by design. There are no usernames, passwords, or emails. Your auth token **is** your identity.

1. You create an account at [a0x13.doxx.net](https://a0x13.doxx.net) (human-only, proof-of-work gated)
2. You give your auth token to the agent
3. The agent makes API calls on your behalf to set up your private network
4. WireGuard configs are generated and installed on your devices

No secrets are stored in this repo. Tokens are always provided by you at runtime.

## License

MIT

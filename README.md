<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/logo-light.png">
  <source media="(prefers-color-scheme: light)" srcset="assets/logo-dark.png">
  <img alt="doxx.net" src="assets/logo-dark.png" width="180">
</picture>

# doxx-skills

AI agent skills for setting up and managing [doxx.net](https://doxx.net) private networks through natural language.

## Requirements

- A doxx.net account (create one at [a0x13.doxx.net](https://a0x13.doxx.net))

## Getting Started

### Claude Code

Clone the repo (required while the repo is private — once public, this will be replaced with a direct marketplace install):

```bash
git clone https://github.com/doxxcorp/doxx-skills.git
```

**CLI:**

```bash
cd doxx-skills
claude /plugin marketplace add ./claude
claude /plugin install doxxnet
```

**VS Code / Cursor:**

1. Open the plugin manager with `/plugins`
2. Switch to the **Marketplaces** tab and add the path to the `claude/` directory inside your clone (e.g. `~/doxx-skills/claude/`)
3. Switch to the **Plugins** tab and search for "doxx" — **doxxnet** will appear
4. Click **Install** and choose your scope

**Set your auth token** so skills can authenticate automatically:

```bash
# Add to ~/.zshrc or ~/.bashrc
export DOXXNET_TOKEN=your-token-here
```

If launching from an IDE, restart it after updating your shell profile so it picks up the new env var.

Once installed, use any skill as a slash command:

```
/doxxnet:network-wizard
```

If `DOXXNET_TOKEN` is not set, the skill will prompt you for it.

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

## How It Works

doxx.net is anonymous by design. There are no usernames, passwords, or emails. Your auth token **is** your identity.

1. You create an account at [a0x13.doxx.net](https://a0x13.doxx.net) (human-only, proof-of-work gated)
2. You give your auth token to the agent
3. The agent makes API calls on your behalf to set up your private network

No secrets are stored in this repo. Tokens are always provided by you at runtime.

## TODO

- [ ] Make repo public and switch install instructions to marketplace: `/plugin marketplace add doxxcorp/doxx-skills` + `/plugin install doxxnet`

## License

MIT

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/logo-light.png">
  <source media="(prefers-color-scheme: light)" srcset="assets/logo-dark.png">
  <img alt="doxx.net" src="assets/logo-dark.png" width="180">
</picture>

# doxx-skills

AI agent skills for setting up and managing [doxx.net](https://doxx.net) private networks through natural language.

No external dependencies — skills use `curl` for API calls. No Python, no servers, no daemons.

## Requirements

- A doxx.net account (create one at [a0x13.doxx.net](https://a0x13.doxx.net))

## Getting Started

### Claude Code

**CLI:**

```bash
claude /plugin marketplace add doxxcorp/doxx-skills
claude /plugin install doxxnet
```

**VS Code / Cursor:**

1. Open the plugin manager with `/plugins`
2. Switch to the **Marketplaces** tab and click **Add** — enter `doxxcorp/doxx-skills`
3. Switch to the **Plugins** tab and search for "doxx" — **doxxnet** will appear
4. Click **Install** and choose your scope

Use any skill as a slash command:

```
/doxxnet:network-wizard
```

On first use, the skill will ask for your auth token. It validates it and saves it locally to `~/.config/doxxnet/token` — no manual setup needed.

### OpenClaw

```bash
clawhub install doxxnet
```

Or from a local clone:

```bash
openclaw skill install ./openclaw/skills/doxxnet
```

Set your token via environment variable:

```bash
export DOXXNET_TOKEN=your-token
```

See [openclaw/README.md](openclaw/README.md) for full setup.

### Other Agents

Any AI agent with shell access can use the API reference directly:

- **[api/reference.md](api/reference.md)**: Condensed doxx.net API reference optimized for agent consumption

Point your agent at the reference file and provide your doxx.net auth token at runtime.

## What's Inside

### Claude Code Plugin (`claude/`)

Interactive skills with guided workflows:

| Skill | What it does |
|-------|-------------|
| **doxxnet** | General-purpose: tunnels, firewall, domains, DNS blocking, stats — routes to the right API automatically |
| **network-wizard** | Full guided setup: auth, servers, tunnels, mesh networking, domains, DNS blocking, client install |
| **manage-tunnels** | Add/remove/move devices, get WireGuard configs |
| **manage-devices** | List, rename, change icons, and delete devices |
| **manage-addresses** | Assign, release, rotate IPs, lease dedicated IPv4, manage connection profiles |
| **manage-account** | Recovery settings, notifications, recovery codes, subscription status |
| **manage-domains** | Register domains, manage DNS records, sign TLS certificates |
| **manage-firewall** | Open ports, link tunnels, mesh networking rules |
| **manage-dns-blocking** | Enable ad/tracker blocking, manage whitelists/blacklists |
| **network-status** | Bandwidth stats, connection tracking, security alerts |
| **network-stats** | Detailed bandwidth, security alerts, threat categories, peak throughput |

Skills call the doxx.net API directly via `curl` — no intermediate server, no permission prompts.

### OpenClaw Skills (`openclaw/`)

The same 11 skills ported for [OpenClaw](https://openclaw.org). Uses `$DOXXNET_TOKEN` environment variable instead of file-based token storage. See [openclaw/README.md](openclaw/README.md).

### API Reference (`api/`)

- **api/reference.md**: Every doxx.net API endpoint with curl examples — works with any AI agent or can be followed manually

## How It Works

doxx.net is anonymous by design. There are no usernames, passwords, or emails. Your auth token **is** your identity.

1. You create an account at [a0x13.doxx.net](https://a0x13.doxx.net) (human-only, proof-of-work gated)
2. You give your auth token to the agent
3. The agent saves it locally to `~/.config/doxxnet/token` and makes API calls on your behalf

No secrets are stored in this repo. Your token stays on your machine.

## Known Limitations

- **Uninstall only works for user scope from the UI.** "Install for this project" and "Install locally" cannot be uninstalled from the `/plugin` UI due to [upstream scope-tracking bugs](https://github.com/anthropics/claude-code/issues/14202) in Claude Code's plugin system ([#14202](https://github.com/anthropics/claude-code/issues/14202), [#26513](https://github.com/anthropics/claude-code/issues/26513), [#25613](https://github.com/anthropics/claude-code/issues/25613)). Use the CLI as a workaround:

  ```bash
  claude plugin uninstall doxxnet@doxx-skills --scope project
  claude plugin uninstall doxxnet@doxx-skills --scope local
  ```

## License

MIT

# doxx-skills for OpenClaw

AI agent skills for managing [doxx.net](https://doxx.net) private networks via [OpenClaw](https://openclaw.org).

## Install

```bash
clawhub install doxxnet
```

Or from a local clone:

```bash
openclaw skill install ./openclaw/skills/doxxnet
```

## Setup

Set your doxx.net auth token as an environment variable:

```bash
export DOXXNET_TOKEN=your-token
```

Get a token at [a0x13.doxx.net](https://a0x13.doxx.net) (human-only, proof-of-work gated).

## Skills

| Skill | What it does |
|-------|-------------|
| **doxxnet** | General-purpose: tunnels, firewall, domains, DNS blocking, stats |
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

## How It Works

Skills call the doxx.net API directly via `curl`. Your token is read from the `$DOXXNET_TOKEN` environment variable. No intermediate servers, no daemons.

## API Reference

For use outside OpenClaw, see [api/reference.md](../api/reference.md) for the full doxx.net API with curl examples.

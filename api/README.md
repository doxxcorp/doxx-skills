# doxx.net API

## Machine-Readable Reference

The live API self-documents at `https://config.doxx.net/` — no auth required:

```bash
curl -s https://config.doxx.net/ | jq .
```

Returns a JSON manifest with every endpoint, its parameters, return values, auth requirements, and side effects. The `context` field in every API response also contains plain-text documentation of that specific endpoint, designed for AI agents and programmatic consumers.

Full documentation: https://github.com/doxx/doxx.net-api-docs

## Protocol

- **Method:** `POST` to `https://config.doxx.net/v1/`
- **Content-Type:** `application/x-www-form-urlencoded`
- **Endpoint selection:** Set `endpoint_name=1` as a form parameter (e.g. `servers=1`, `list_tunnels=1`)
- **Response:** JSON with `"status": "success"` or `"status": "error"` — HTTP 200 can still be an error

## Authentication

Most endpoints require a `token` form parameter:

```bash
curl -s -X POST https://config.doxx.net/v1/ -d "list_tunnels=1&token=YOUR_TOKEN"
```

Tokens are obtained by creating an account at https://a0x13.doxx.net (human-only, proof-of-work gated). Accounts cannot be created via API.

## Regional Endpoints

| Region | URL | Use |
|--------|-----|-----|
| Round-robin (default) | `https://config.doxx.net/v1/` | Highest availability |
| US East (Virginia) | `https://config-us-east.doxx.net/v1/` | Lowest latency for US East |
| US West (Los Angeles) | `https://config-us-west.doxx.net/v1/` | Lowest latency for US West |
| EU Central (Zurich) | `https://config-eu-central.doxx.net/v1/` | Lowest latency for Europe |

## Plans

| Plan | Features |
|------|----------|
| Free | Account only, no tunnel creation |
| Basic | VPN tunnels, DNS blocklists, basic firewall, 3 device seats |
| Pro | Everything in Basic + dedicated public IPs, advanced proxy, premium blocklists, 5 device seats |
| Pro+ | Everything in Pro with higher limits, 10 device seats, priority support |

Subscribe at https://doxx.net/ops/account/subscription

## Files

- **`reference.md`** — Agent-optimized endpoint reference with curl examples for all config API and stats API endpoints

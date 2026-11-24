# doxx.net API

## Machine-readable reference

The live API describes itself. A GET to `https://config.doxx.net/` returns a JSON manifest: every endpoint with its params, returns, auth, minimum role and side effects, plus the terminology and `use_cases` recipes. No token is needed:

```bash
curl -s https://config.doxx.net/ | jq '.endpoints | keys'
```

Every API response also carries a `context` field with plain-text help for that endpoint, written for agents. The full, current list of endpoints is the live manifest at https://config.doxx.net/ (a GET, no token).

`reference.md` in this directory is a dated snapshot of that manifest, checked against the handler code (see its "Known manifest errors" section).

## Protocol

- **Config API:** `POST https://config.doxx.net/v1/`, `Content-Type: application/x-www-form-urlencoded`.
- **Endpoint selection:** set `<endpoint>=1` as a form parameter (for example `servers=1`, `list_tunnels=1`). Other fields are the endpoint's params.
- **Response:** JSON with `"status": "success"` or `"status": "error"`. HTTP 200 can still be an error: always check `status`. Errors carry `message`, often `context`, `fix`, `error_code` and `upgrade_url`.
- **Stats API:** `POST` or `GET https://secure-wss.doxx.net/api/stats/<endpoint>`, params in the query string, token in the `X-Auth-Token` header. Errors are plain text.

## Authentication

Most endpoints need the account token as the `token` form param. Keep it out of the command line and out of the conversation: read it from `DOXX_TOKEN` or `~/.config/doxx/token` (legacy: `DOXXNET_TOKEN`, `~/.config/doxxnet/token`) and pipe it into curl on stdin (`--data-urlencode "token@-"`, or a curl config read with `-K -`, which also keeps a `tunnel_token` out of the command line). The exact command is in the "Calling the API" section of `reference.md`.

Every token has a role: `admin` (everything, including tokens and billing), `net-admin` (tunnels, DNS, firewall, domains, profiles, agents), `read-only`, or `device` (a gateway credential bound to one tunnel). Give an AI agent a dedicated `net-admin` token with a 7 to 30 day expiry.

Accounts and tokens are created by a person in the portal at https://app.doxx.net (account creation is proof-of-work gated and cannot be done through the API). Recovery codes are managed there too. If doxx MCP tools are present in a session, they call the same endpoints and inject the token.

## Regional endpoints

Same API, same data, same `/v1/` path:

| Region | URL | Use |
|--------|-----|-----|
| Round-robin (default) | `https://config.doxx.net/v1/` | Highest availability |
| US East (Virginia) | `https://config-us-east.doxx.net/v1/` | Lowest latency for US East |
| US West (Los Angeles) | `https://config-us-west.doxx.net/v1/` | Lowest latency for US West |
| EU Central (Zurich) | `https://config-eu-central.doxx.net/v1/` | Lowest latency for Europe |

## Plans

Plans are Free, Essentials (the API slug is `basic`) and Pro. Pro+ is legacy and no longer sold. What each plan includes, seat counts and prices change, so they are not listed here:

- The account's own plan, status, seats and locked features: `POST https://payments.doxx.net/v1/access/status` with the token.
- The public price list: `curl -s https://payments.doxx.net/v1/pricing` (no token).
- Plan changes, extra seats and add-ons are made by the user at https://app.doxx.net/ops/account/subscription.

## Files

- **`reference.md`**: agent-optimized endpoint reference for the Config API and the Stats API, one entry per endpoint (purpose, role, params, returns, gates, side effects) with curl examples.

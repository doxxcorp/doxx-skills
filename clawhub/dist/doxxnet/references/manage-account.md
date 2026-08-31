# Manage doxx.net Account

> **Live schema first.** The doxx.net Config API is agent-descriptive. Fetch `https://config.doxx.net/` for the current manifest (every endpoint, params, returns, auth, side effects): this file is a snapshot. Every POST response also includes a `context` field with per-endpoint docs.

You help users manage their doxx.net account: recovery contact settings, notification preferences, recovery codes, and account deletion. (Subscription and seats live in the a0x13 portal, not the Config API.)


## API convention

**Auth token -- never enters the AI conversation.**

The token is passed to `curl` via shell expansion, so its plaintext value stays on your machine. Two sources, checked in this order:

1. `$DOXXNET_TOKEN` env var (preferred): user exports it before launching the agent.
2. `~/.config/doxxnet/token` file: used automatically if the env var is unset.

curl commands below use `${DOXXNET_TOKEN:-$(cat ~/.config/doxxnet/token)}`, so both work transparently. The shell expands the value at exec time -- the plaintext is never emitted in a tool call to the LLM.

**Config API**: POST to `https://config.doxx.net/v1/`:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=${DOXXNET_TOKEN:-$(cat ~/.config/doxxnet/token)}"
```

## Endpoints

- `get_profile`: get account profile. Returns: `email` (opt-in recovery email, may be empty), `phone` (opt-in recovery phone, may be empty), whether notifications are enabled, and whether recovery codes exist + how many remain. Recovery contact is opt-in only.
- `update_profile`: update recovery contact and notification preferences. Params (all optional): `email` (valid format, or empty to clear), `phone` (international format like `+15551234567`, or empty to clear), `notifications_enabled` (`0` or `1`)
- `create_account_recovery`: generate new recovery codes. Returns: `codes[]`
- `verify_account_recovery`: verify recovery code (for account recovery flow). Returns: `new_token`
- `delete_account` (admin): permanently delete the account and everything it holds. Irreversible; terminates all tunnel connections immediately
- **Subscription is no longer a Config API endpoint.** `subscription_status` and `merge_account` were removed in API 1.1.0. Subscription tier and seats are managed in the a0x13 portal (`https://a0x13.doxx.net/ops/account/subscription`) -- direct the user there rather than calling an endpoint.
- For token management (create/revoke tokens, set expiry, geo/IP fences, tunnel scoping): see the `manage-tokens` skill
- For AI-agent principals (create/list/delete agents for the doxxGateway): see the `manage-agents` skill

## Guidelines

- Always show current profile before making changes (call get_profile first)
- When generating recovery codes, strongly warn user to save them securely
- Remind users that doxx.net has no passwords: the token IS identity, recovery codes are the backup
- Never display recovery codes in a way that could be accidentally shared
- If the user asks about their subscription or tier, point them to the a0x13 portal (subscription is no longer exposed via the Config API)
- For account recovery flow, explain that verify_account_recovery issues a new token and the old one is invalidated
- Always check API response `status` field -- HTTP 200 can still be an error

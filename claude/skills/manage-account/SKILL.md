---
name: manage-account
description: "Manage doxx.net account: recovery settings, notifications, recovery codes, and subscription status"
argument-hint: "[action] [setting]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(cat *), Read, Write
---

# Manage doxx.net Account

> **Live schema first.** The doxx.net Config API is agent-descriptive. Fetch `https://config.doxx.net/` for the current manifest (every endpoint, params, returns, auth, side effects): this file is a snapshot. Every POST response also includes a `context` field with per-endpoint docs.

You help users manage their doxx.net account settings, recovery options, and subscription.

User request: $ARGUMENTS

## API convention

**IMPORTANT: token security -- must never enter the AI conversation.**

The token is passed to `curl` via shell expansion, so its plaintext value stays on your machine. Two sources, checked in this order:

1. `$DOXXNET_TOKEN` env var (preferred, zero exposure): the user exports it before launching Claude Code. curl commands below reference it as `$DOXXNET_TOKEN`; the shell expands it at exec time, so the actual value is never emitted in a tool call.
2. `$(cat ~/.config/doxxnet/token)` inline subshell fallback if the env var is unset (same shell-expansion property: the value never enters the assistant's context).

Never use the `Read` tool on `~/.config/doxxnet/token`: doing so would load the plaintext into the AI conversation and ship it to Anthropic on every subsequent tool call. `Write` is fine to save a token the user just pasted (one-time exposure). Bash is used only for `curl` commands and inline `cat` fallback.

If `$DOXXNET_TOKEN` is unset and no token file exists, ask the user to either `export DOXXNET_TOKEN=your-token` in their shell (zero exposure, restart the session) or paste the token here to save to `~/.config/doxxnet/token` (one-time exposure, then future sessions use the subshell fallback). Validate with `curl -s -X POST https://config.doxx.net/v1/ -d "auth=1&token=$DOXXNET_TOKEN"` (or substitute `$(cat ~/.config/doxxnet/token)` if using the file).

**Config API**: POST to `https://config.doxx.net/v1/`:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=$DOXXNET_TOKEN"
```

The `$DOXXNET_TOKEN` shown in curl examples is expanded by the shell at exec time. If the env var is unset, substitute `$(cat ~/.config/doxxnet/token)` inline within the curl args instead. Never inline the plaintext token value into a tool call.

## Endpoints

- `get_profile`: get account profile. Returns: recovery_email, recovery_phone, email_notifications, sms_notifications, recovery_codes_count
- `update_profile`: update settings. Params: any of `recovery_email`, `recovery_phone`, `notifications`
- `create_account_recovery`: generate new recovery codes. Returns: `codes[]`
- `verify_account_recovery`: verify recovery code (for account recovery flow). Returns: `new_token`
- `subscription_status`: check subscription. Returns: has_active_subscription, tier, subscription (original_transaction_id, product_id, tier, effective_tier, status, purchase_date, expires_date, is_trial, auto_renew), pro_features map
- For token management (create/revoke tokens, set expiry, geo/IP fences, tunnel scoping): see the `manage-tokens` skill

## Guidelines

- Always show current profile before making changes (call get_profile first)
- When generating recovery codes, strongly warn user to save them securely
- Remind users that doxx.net has no passwords: the token IS identity, recovery codes are the backup
- Never display recovery codes in a way that could be accidentally shared
- When showing subscription, explain what the current tier includes
- For account recovery flow, explain that verify_account_recovery issues a new token and the old one is invalidated
- Always check API response `status` field: HTTP 200 can still be an error

---
name: manage-account
description: "Manage doxx.net account: recovery settings, notifications, recovery codes, and subscription status"
version: 1.0.0
homepage: https://github.com/doxxcorp/doxx-skills
user-invocable: false
metadata.openclaw: {"env": ["DOXXNET_TOKEN"], "bins": ["curl"], "primaryEnv": "DOXXNET_TOKEN"}
---

# Manage doxx.net Account

You help users manage their doxx.net account settings, recovery options, and subscription.

User request: $ARGUMENTS

## API convention

Token is provided via `$DOXXNET_TOKEN` environment variable.

**Config API**: POST to `https://config.doxx.net/v1/`:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=$DOXXNET_TOKEN"
```

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
- Always check API response `status` field -- HTTP 200 can still be an error

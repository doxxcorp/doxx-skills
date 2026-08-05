---
name: manage-devices
description: "Manage doxx.net devices: list, rename, change icons, and delete devices"
argument-hint: "[action] [device name]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(cat *), Read, Write
---

# Manage doxx.net Devices

> **Live schema first.** The doxx.net Config API is agent-descriptive. Fetch `https://config.doxx.net/` for the current manifest (every endpoint, params, returns, auth, side effects): this file is a snapshot. Every POST response also includes a `context` field with per-endpoint docs.

You help users manage their doxx.net devices. Each device on the network can be listed, renamed, have its icon changed, or be deleted.

User request: $ARGUMENTS

## API convention

**IMPORTANT: token security -- must never enter the AI conversation.**

The token is passed to `curl` via shell expansion, so its plaintext value stays on your machine. Two sources, checked in this order:

1. `$DOXXNET_TOKEN` env var (preferred): user exports it before launching Claude Code.
2. `~/.config/doxxnet/token` file: used automatically if the env var is unset.

curl commands below use `${DOXXNET_TOKEN:-$(cat ~/.config/doxxnet/token)}` so both work transparently -- the shell expands the value at exec time and the plaintext is never emitted in a tool call.

Never use the `Read` tool on `~/.config/doxxnet/token`: doing so would load the plaintext into the AI conversation and ship it to Anthropic on every subsequent tool call. `Write` is fine to save a token the user just pasted (one-time exposure). Bash is used only for `curl` commands and inline `cat` fallback.

If `$DOXXNET_TOKEN` is unset and no token file exists, ask the user to either `export DOXXNET_TOKEN=your-token` in their shell (zero exposure, restart the session) or paste the token here to save to `~/.config/doxxnet/token` (one-time exposure, then future sessions use the file fallback automatically). Validate with `curl -s -X POST https://config.doxx.net/v1/ -d "auth=1&token=${DOXXNET_TOKEN:-$(cat ~/.config/doxxnet/token)}"`.

**Config API**: POST to `https://config.doxx.net/v1/`:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=${DOXXNET_TOKEN:-$(cat ~/.config/doxxnet/token)}"
```

The `${DOXXNET_TOKEN:-$(cat ~/.config/doxxnet/token)}` shown in curl examples is expanded by the shell at exec time -- the env var if set, otherwise the file. Never inline the plaintext token value into a tool call, and never `Read` the token file.

## Endpoints

- `device_list_unified`: list all devices with subscription info and guest accounts. Returns:
  - `my_devices[]`: each has device_hash, device_name, device_model, os_type (ios/macos/android/windows/linux), device_type (mobile/server/desktop/tablet), device_icon, is_current, is_online, last_seen, tunnel_count, has_seat, is_owner, can_remove, can_rename, can_delete
  - `guest_accounts[]`: each has profile_name, devices[]
  - `subscription`: { exists, tier, status, device_count, max_devices, is_account_owner }
- `device_rename`: rename device or change icon. Params: `device_hash`, `device_name`. Optional: `device_icon`
- `device_delete`: permanently delete a device (removes all tunnels, IPs, and seats). Params: `target_device_hash`

## Guidelines

- Always call `device_list_unified` first to show current state
- Show subscription info (tier, device_count/max_devices) when listing
- Check `can_delete`, `can_rename` flags before attempting operations
- Confirm with user before deleting (permanent, removes tunnels and IPs)
- Warn that `device_delete` is irreversible
- Present devices in a clear table with name, model, OS, online status, tunnel count, seat status
- When showing guest accounts, group them separately
- Always check API response `status` field: HTTP 200 can still be an error

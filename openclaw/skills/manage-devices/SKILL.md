---
name: manage-devices
description: "Manage doxx.net devices: list, rename, change icons, and delete devices"
version: 1.0.0
homepage: https://github.com/doxxcorp/doxx-skills
user-invocable: true
metadata.openclaw: {"env": ["DOXXNET_TOKEN"], "bins": ["curl"], "primaryEnv": "DOXXNET_TOKEN"}
---

# Manage doxx.net Devices

You help users manage their doxx.net devices. Each device on the network can be listed, renamed, have its icon changed, or be deleted.

User request: $ARGUMENTS

## API convention

Token is provided via `$DOXXNET_TOKEN` environment variable.

**Config API** — POST to `https://config.doxx.net/v1/`:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=$DOXXNET_TOKEN"
```

## Endpoints

- `device_list_unified` — list all devices with subscription info and guest accounts. Returns:
  - `my_devices[]`: each has device_hash, device_name, device_model, os_type (ios/macos/android/windows/linux), device_type (mobile/server/desktop/tablet), device_icon, is_current, is_online, last_seen, tunnel_count, has_seat, is_owner, can_remove, can_rename, can_delete
  - `guest_accounts[]`: each has profile_name, devices[]
  - `subscription`: { exists, tier, status, device_count, max_devices, is_account_owner }
- `device_rename` — rename device or change icon. Params: `device_hash`, `device_name`. Optional: `device_icon`
- `device_delete` — permanently delete a device (removes all tunnels, IPs, and seats). Params: `target_device_hash`

## Guidelines

- Always call `device_list_unified` first to show current state
- Show subscription info (tier, device_count/max_devices) when listing
- Check `can_delete`, `can_rename` flags before attempting operations
- Confirm with user before deleting (permanent, removes tunnels and IPs)
- Warn that `device_delete` is irreversible
- Present devices in a clear table with name, model, OS, online status, tunnel count, seat status
- When showing guest accounts, group them separately
- Always check API response `status` field -- HTTP 200 can still be an error

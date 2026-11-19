# Manage doxx.net Agents

You help users manage doxx.net **agents**: AI-agent chat principals that run on the doxxGateway. This skill covers the platform side through the Config API: create, list, edit, re-host and delete the agent. Running the agent (the doxxGateway binary, its local agent API) lives in the gateway repo, not here.

<!-- runtime:claude,openclaw -->
User request: $ARGUMENTS
<!-- /runtime -->

## What an agent is

<!-- runtime:claude -->
A doxx.net **agent** is an owned sub-friend of your account, not a separate account. Key facts to convey to the user:
<!-- /runtime -->
<!-- runtime:openclaw,codex -->
A doxx.net **agent** is an owned sub-friend of your account, not a separate account:
<!-- /runtime -->

- **No new account.** An agent has a chat identity but no user, no login token and no bill of its own. Your devices see it as a friend; you see every conversation it has.
- **It is hosted on one of your devices.** The doxxGateway binary (https://github.com/doxxcorp/gateway) hosts it on a Linux machine (`kind=agent`, the machine takes its own device seat), or the doxx.net app hosts it on a Mac (`kind=device_agent`, sharing that Mac's seat). The host holds a `device` credential (`create_token role=device`), which the gateway's own setup mints. A `kind=webhook` agent is a post-only receiver hosted on one of your devices: outside systems post to it and the text lands in chat as the agent.
- **Plan gate.** Agents need the `agents` feature: Essentials and Pro include agents, Free does not. How many the plan allows is live in the entitlements (`limits.agents`; webhooks count too). The account also needs a profile name.
- **Owner-only by default.** New agents start `owner_only=1`: they reach you and nobody else. `update_agent owner_only=0` unlocks friend links. Even then every contact is **double opt-in**: the person must be your active friend AND accept the agent through an introduction.
- **Agent-to-agent chat is off** unless `a2a_enabled=1` is set on both agents.

**Two layers, do not mix them up.** This skill manages the agent's directory entry on doxx.net. The agent's own chat (send, wait for messages, files, contacts) is a separate API served by the gateway on its host. The gateway also speaks MCP for that chat API: point an MCP client at the command `doxxGateway mcp` (or `ssh <host> doxxGateway mcp`). Its tools (`chat_send`, `wait_for_message` and others) are chat tools, not network management.

<!-- include: transport -->

<!-- include: operating-rules -->

<!-- include: errors -->

<!-- include: plans -->

## Endpoints

- `create_agent` (net-admin): create an agent. Params: `agent_name` (required, max 64 chars: the friend name your devices show). Optional: `kind` (`agent` default, `device_agent` or `webhook`), `a2a_enabled=1`. Returns `agent_id`, `agent_name`, `kind`, `a2a_enabled`, `notes`. The agent is paired to you as a friend at once. No token is minted here.
  - Refusals: `feature_required` with `feature: "agents"` (no agents on this plan) or `feature: "p2p"` (the account has no chat at all, for example a paused one), `agent_limit` (all agent seats used), 400 "Set your profile name before creating an agent".
- `list_agents`: the account's agents. Each has `agent_id`, `agent_name`, `kind`, `a2a_enabled`, `owner_only`, `status`, `bound` (has a host), `credentials` (live device credentials for this agent), `pair_count`, `created_at`. A hosted agent also has `bound_device_hash`, `host_name` (same as `bound_device_name`), `host_os`, `host_tunnel_name`, `host_online` (the host's tunnel is up) and `host_tunnel_token` (a credential: never print it). Whether the agent is answering right now is not here: presence travels over the mesh.
- `update_agent` (net-admin): edit an agent. Params: `agent_id` (required). Optional, each independent (omitted fields stay): `agent_name` (rename; every pair sees the new name), `owner_only` (`1` or `0`), `a2a_enabled` (`1` or `0`), `host_device_hash` (move the agent to another of your devices: a `device_hash` from `device_list_unified`; an empty value unhosts it). Returns `agent_id`, `changed`, and a `note` on a re-host. The host gateway picks the change up within about a minute.
  - Re-hosting or unhosting **revokes the old host's credentials for this agent at once**: the old host stops speaking as the agent. The new host claims the agent on its next check and mints its own credential.
  - `motd` (the status line) is refused with 410: it travels over the mesh from the owner's device, not through this API. A deleted agent answers 410 too.
<!-- runtime:claude -->
- `delete_agent` (admin): delete an agent you own. It revokes all its pairs (yours, introduced friends, agent-to-agent), clears its host, and revokes its device credential. Params: `agent_id` (required). Returns: `deleted_agent_id`, `notes`. The device row and tunnel remain (remove them with `delete_tunnel` if the machine is going away); the chat-identity certificate lives on the host and dies with it.
<!-- /runtime -->
<!-- runtime:openclaw,codex -->
- `delete_agent` (admin): delete an agent you own. Revokes all its pairs and its device credential, clears its host. Params: `agent_id` (required). Returns: `deleted_agent_id`, `notes`. The device and tunnel remain (remove with `delete_tunnel`); the chat-identity certificate lives on the host and dies with it.
<!-- /runtime -->

Show agents without their tunnel tokens, for example:

```
printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ -d "list_agents=1" --data-urlencode "token@-" | jq '.agents // [] | map(del(.host_tunnel_token))'
```

### Legacy bots (deprecated)

<!-- runtime:claude -->
Bot accounts are replaced by agents. `create_bot` returns **HTTP 410** (`create_bot_deprecated`): no new bots. Use these only to inspect and clean up existing bots:
<!-- /runtime -->
<!-- runtime:openclaw,codex -->
Bot accounts are replaced by agents. `create_bot` returns **HTTP 410** (`create_bot_deprecated`). Use these only to inspect and clean up existing bots:
<!-- /runtime -->

- `list_bots`: Returns `bots[]` with `bot_user_id`, `bot_name`, `tunnel_count`, `seated`, `online`, `created_at`.
- `delete_bot` (admin): delete a legacy bot and everything it holds (user row, token, profile, seat grant, pairs, tunnels). The seat returns to the plan. Params: `bot_user_id` (required). Irreversible.

## Guidelines

<!-- runtime:claude -->
- Always call `list_agents` first to show current agents and where each is hosted before creating, editing or deleting.
- Before `create_agent`, check the live entitlements: the `agents` feature and `limits.agents` (used and max). On `feature_required` or `agent_limit`, show `message` and `upgrade_url` verbatim and stop; never buy agent seats or change the plan.
- On `create_agent`, tell the user what this skill does NOT do: install and run the doxxGateway on the host machine (or turn on the Agent Gateway in the doxx.net app on a Mac), which hosts the agent. Point them at https://github.com/doxxcorp/gateway and the `chat_bot_gateway_for_ai_agents` recipe in the live manifest.
- Confirm before each `update_agent` that renames or re-hosts. Say what happens: a rename shows the new name to everyone the agent is paired with; a re-host or unhost cuts the current host off at once, and the agent is silent until the new host claims it.
- Confirm before `owner_only=0`: friends the user introduces can then reach the agent (each still has to accept).
- Only suggest `a2a_enabled=1` when the user wants agent-to-agent chat; it must be on for both agents and the owner still approves the pairing.
- Confirm before `delete_agent` (the chat identity is gone for good) and before `delete_bot` (removes tunnels and returns the seat).
<!-- /runtime -->
<!-- runtime:openclaw,codex -->
- Always call `list_agents` first before creating, editing or deleting.
- Before `create_agent`, check the entitlements (`agents` feature, `limits.agents`). On `feature_required` or `agent_limit`, show `message` and `upgrade_url` and stop; never buy seats.
- On `create_agent`, remind the user that hosting is a separate step: run the doxxGateway (https://github.com/doxxcorp/gateway) or the Mac app's Agent Gateway. Point them at the `chat_bot_gateway_for_ai_agents` recipe.
- Confirm before a rename or re-host with `update_agent`: a rename is seen by every pair; a re-host or unhost cuts the old host off at once.
- Confirm before `owner_only=0`.
- Only suggest `a2a_enabled=1` when the user wants agent-to-agent chat; it must be set on both agents.
- Confirm before `delete_agent` and `delete_bot` (irreversible).
<!-- /runtime -->
- If a user asks to "create a bot," tell them bots are deprecated and create an agent instead.
- Never print `host_tunnel_token` or any credential from these responses; name the host device and tunnel instead.

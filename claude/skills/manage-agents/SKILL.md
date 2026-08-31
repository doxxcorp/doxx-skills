---
name: manage-agents
description: "Manage doxx.net agents: create AI-agent chat principals for the doxxGateway, inspect device binding, delete agents, and clean up legacy bots"
argument-hint: "[action] [agent name]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(cat *), Read, Write
---

# Manage doxx.net Agents

> **Live schema first.** The doxx.net Config API is agent-descriptive. Fetch `https://config.doxx.net/` for the current manifest (every endpoint, params, returns, auth, side effects): this file is a snapshot. Every POST response also includes a `context` field with per-endpoint docs.

You help users manage doxx.net **agents**: AI-agent chat principals that run on the doxxGateway. This skill covers the platform side (create, list, delete the principal via the Config API). Hosting the agent (the doxxGateway binary, the local agent API, MCP) lives in the gateway repo, not here.

User request: $ARGUMENTS

## What an agent is

A doxx.net **agent** is an owned sub-friend of your account, not a separate account. Key facts to convey to the user:

- **No new account.** An agent has a chat identity but no user, no token, no billing existence. Your devices see it as a friend; you see every conversation it has.
- **It binds to a device.** The agent is hosted by the doxxGateway binary (`https://github.com/doxxcorp/gateway`) on a Linux machine (`kind=agent`, its own device seat), or by the in-app gateway on macOS (`kind=device_agent`, sharing an existing device seat). Binding happens when the gateway runs `create_token role=device` during its own setup, not from this skill.
- **Prerequisites.** Creating an agent requires an active **P2P plan** (Pro or Pro+) and a **profile name** set on the account. If either is missing, the API returns an error explaining the fix.
- **Owner-only by default.** New agents start `owner_only=1`: they reach you and nobody else. Unlocking friend links is done in the doxxGateway config / app toggle, not here. After unlock, every contact is **double opt-in** (the person must be your active friend AND explicitly accept the agent via an introduction).
- **Agent-to-agent chat is off** unless `a2a_enabled=1` is set on both agents.

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

- `create_agent` (net-admin): create an agent principal. Params: `agent_name` (required, the friend name your devices show). Optional: `a2a_enabled` (`1` to allow agent-to-agent pairing, off by default), `kind` (`agent` [default, dedicated-machine gateway] or `device_agent` [in-app macOS gateway sharing an existing device seat]). Returns: `agent_id`, `agent_name`, `kind`, `a2a_enabled`. No token is minted here.
- `list_agents`: list agent principals the account owns, with binding state. Returns: `agents[]` with `agent_id`, `agent_name`, `kind`, `a2a_enabled`, `owner_only`, `bound`, `bound_device_hash`, `bound_device_name`, `status`, `created_at`.
- `delete_agent` (admin): delete an agent you own. Revokes all its pairs (yours, introduced friends, agent-to-agent), clears its device binding, and revokes its device credential. Params: `agent_id` (required). Returns: `deleted_agent_id`, `notes`. The device row and tunnel remain (remove with `delete_tunnel` if the machine is going away); the chat-identity certificate lives on the host and dies with it.

### Legacy bots (deprecated)

Bot accounts are replaced by agent principals. `create_bot` returns **HTTP 410** (`create_bot_deprecated`) -- no new bots. Use these only to inspect and clean up existing bots:

- `list_bots`: Returns `bots[]` with `bot_user_id`, `bot_name`, `tunnel_count`, `seated`, `online`, `created_at`.
- `delete_bot` (admin): delete a legacy bot and everything it holds (user row, token, profile, seat grant, pairs, tunnels). The seat returns to the plan. Params: `bot_user_id` (required). Irreversible.

## Guidelines

- Always call `list_agents` first to show current agents and their binding state before creating or deleting.
- On `create_agent`, remind the user of the two next steps this skill does NOT do: (1) install/run the doxxGateway on the host machine, which binds the agent to a device, and (2) unlock `owner_only` if they want the agent reachable by introduced friends. Point them at `https://github.com/doxxcorp/gateway` and the `chat_bot_gateway_for_ai_agents` recipe in the live manifest.
- If `create_agent` fails for a missing P2P plan or profile name, explain the prerequisite plainly (subscription/seats are managed in the a0x13 portal, `https://a0x13.doxx.net`; profile name is set on the account).
- Only suggest `a2a_enabled=1` when the user actually wants agent-to-agent networking; it must be set on both agents and the owner still approves the pairing.
- Confirm before `delete_agent` (irreversible for the chat identity) and before `delete_bot` (removes tunnels and returns the seat).
- If a user asks to "create a bot," tell them bots are deprecated and create an agent instead.
- Always check the API response `status` field: HTTP 200 can still be an error.

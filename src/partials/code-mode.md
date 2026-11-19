## Batching calls (Code Mode)

For work that needs many reads, run one short program that makes the calls, joins and filters the answers in the shell, and prints only the summary. The conversation gets a few lines instead of raw JSON, the result is the same every time, and secrets such as `tunnel_token` never leave the shell.

**When to batch:**

- Three or more calls feed one answer (for example tunnels, stats and alerts for a status overview).
- A fan-out: the same call once per tunnel or per server.
- A large answer you need only a few fields from.
- Polling: waiting for a state to change.

**When to make single calls:** one question that one or two reads answer.

**Writes:**

- A single write is always one call, after the user confirms, with its `status` and `context` checked before the next call. A failure then never leaves a half-applied change.
- A bulk write (the same change on many tunnels) may run in a script, but the script must first print the planned calls as a dry run (endpoint, tunnel name and values, never a token). Show that plan to the user, and run it with `--apply` only after a clear yes. It still makes the calls one at a time and stops at the first error.

**Prefer the bundled scripts.** Some skills ship ready scripts in a `scripts/` directory, with their shared helper in `lib/`. `<skill dir>` below means the skill's root directory: the one that holds its `SKILL.md` (or `AGENTS.md`) and the `scripts/` and `lib/` directories. Run a script with `bash <skill dir>/scripts/<name>.sh`; each one takes `--help`, is read-only unless it says otherwise, and prints the endpoints it called. Write your own bash + curl + jq script only when no bundled script fits, and follow the same rules:

- Check `command -v jq` first: the scripts need `jq`. Without it, do not batch: make single calls, and none whose answer carries secrets (see "Calling the API").
- If `<skill dir>/lib/doxx.sh` exists, source it instead of writing curl calls by hand. `doxx_require` checks curl, jq and the token, and prints the endpoints called when the script ends. `doxx_call ENDPOINT key=value ...` (Config API) and `doxx_stats ENDPOINT key=value ...` (Stats API) put the answer in `$DOXX_OUT`, stop on an error with the API's message, and keep the auth token out of every command line. `doxx_names "$tunnels" "$answer" FILTER` maps tokens to tunnel names.
- Never print the auth token or a `tunnel_token`. Map tokens to tunnel names inside the script; if a token must be shown at all, show only its first 4 characters and "…".
- Make the calls one after another, never in parallel, and respect the rate limits (`network_info`: 30 calls a minute per account).
- Stop at the first error and print the API's `message` (Stats errors are plain text).
- At the end, print the list of endpoints the script called, so the user sees what ran.

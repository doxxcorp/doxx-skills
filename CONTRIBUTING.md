# Contributing to doxx-skills

## Prerequisites

- `bash`, `awk`, `make`
- `python3`
- `curl` and `jq` (Code Mode scripts, their tests, and `make api-drift`)
- `shellcheck` (optional locally: `make validate` skips it with a warning when it is
  missing; CI installs it and fails without it)

## Editing skills

Every skill has one source under `src/skills/<name>/`. The runtime trees
(`claude/skills/`, `openclaw/skills/`, `codex/skills/`) are generated from it:
never edit them by hand.

1. Edit the source:
   - `body.md`: the skill body shared by all runtimes.
   - `frontmatter.claude.yml` / `frontmatter.openclaw.yml`: the YAML frontmatter for
     each runtime, copied verbatim between `---` lines (LF line endings, ending with a
     newline). Codex `AGENTS.md` has none. OpenClaw frontmatter says
     `version: {{version}}`: the build stamps the version from `VERSION`.
   - `evals.json`: copied to `claude/skills/<name>/evals/evals.json`.
   - `scripts/` (optional): copied into every runtime's skill directory, together with
     `src/lib/doxx.sh` as `lib/doxx.sh`. Skill text names them as
     `<skill dir>/scripts/<name>.sh`; `make validate` fails if a named file is not shipped.
2. Wrap text that only applies to some runtimes in block markers, each on its own line:

   ```markdown
   <!-- runtime:claude,openclaw -->
   User request: $ARGUMENTS
   <!-- /runtime -->
   ```

   Valid runtimes: `claude`, `openclaw`, `codex`. Blocks do not nest.
3. Shared text used by several skills can live in `src/partials/<partial>.md` and be
   pulled in with a line `<!-- include: <partial> -->`. Includes are resolved before
   runtime blocks are filtered, so a partial may contain runtime blocks.
4. Run `make build` and commit the generated files together with the source.

Everything directly under `claude/skills/`, `openclaw/skills/` and `codex/skills/` is
generated and is deleted and rebuilt on every `make build`: keep nothing else there.

`make build-check` regenerates and fails if the generated trees differ from what is
committed, so drift between `src/` and the runtime trees is caught.

## ClawHub bundle

`make clawhub` builds `clawhub/dist/doxxnet/` from the OpenClaw tree: the `doxxnet`
skill, every other skill as `references/<name>.md`, and all Code Mode scripts in one
`scripts/` directory next to `lib/doxx.sh`. Script names must be unique across skills.
The build fails if a file in the bundle names a script the bundle does not ship.
`make clawhub-check` rebuilds and fails if the committed bundle is stale.

## Versioning

The version lives in `VERSION` only. On a release, change `VERSION`, the `version` in
`.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, add a `## <version>`
entry to `CHANGELOG.md`, then run `make build clawhub`. `make validate` fails if any of
these disagree.

## API drift

`api/reference.md` is a snapshot of the live Config API. `make api-drift` fetches the
live manifest (`curl -s https://config.doxx.net/`, a GET with no token) and lists endpoints that are
missing from the reference or documented but no longer in the manifest. It exits 1 on
drift. Endpoints documented on purpose without a manifest entry (curl-only or
handler-only) go in `api/drift-allowlist.txt` with a reason. To run it offline against a
saved manifest: `make api-drift MANIFEST=path/to/manifest.json`.

It needs the network, so it is not part of `make validate`. Run it before a release and
whenever the API changes.

`.github/workflows/api-drift.yml` also runs it every day, on demand (`workflow_dispatch`),
and on pull requests that touch the check or `api/reference.md`. On scheduled and manual
runs `scripts/api-drift-report.sh` keeps one tracking issue titled "api-drift:
api/reference.md is behind the live Config API manifest": it opens the issue on drift,
comments only when the drift output changes, and closes it when the drift is gone. A
manifest that cannot be fetched (exit 2) fails the run but leaves the issue alone. The
check compares endpoint names only, so params and returns still need a manual review.

## Adding a New Skill

1. Create a directory under `src/skills/your-skill-name/` with a `body.md`.
2. Write `frontmatter.claude.yml` (and `frontmatter.openclaw.yml`, see an existing skill for the `metadata.openclaw` block):

```yaml
name: your-skill-name
description: "Short description (max 200 chars)"
argument-hint: "[action] [target]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(printf *), Write
```

3. The `name` field must match the directory name (lowercase, hyphenated).
4. Add evals in `src/skills/your-skill-name/evals.json`:

```json
{
  "evals": [
    {
      "id": "your-eval-id",
      "prompt": "User prompt to test",
      "expectations": ["Expected behavior or API call"]
    }
  ]
}
```

5. If your skill references API endpoints, ensure they are documented in `api/reference.md`.
6. Write `version: {{version}}` in `frontmatter.openclaw.yml`, and keep `description` at 200 characters or fewer.
7. Add `./claude/skills/<name>/` to the `skills` array in `.claude-plugin/plugin.json` (Claude Code loads only the listed skill directories; `make validate` checks that every skill in `src/skills` is listed).
8. Run `make build` to generate the Claude, OpenClaw and Codex copies, and `make clawhub` to refresh the ClawHub bundle.

## Running Validation

```bash
make check      # build-check + clawhub-check + validate: everything offline a PR must pass
make validate   # validation only (fast, offline)
make test       # Code Mode script tests against a fake API (offline)
```

`make validate` checks:

- Required files exist
- plugin.json is valid and references existing skills
- SKILL.md frontmatter has required fields (name, description)
- Skill names match directory names
- Internal markdown links resolve
- All API endpoints referenced in skills exist in `api/reference.md`, and every `"<endpoint>=1` form anywhere in the sources, docs and evals is a `### <endpoint>` heading there
- No public text names an endpoint the live manifest hides (an eval says "calls only endpoints in the public manifest" instead)
- Evals are present and well-formed
- OpenClaw skills have valid frontmatter and metadata (`requires.env [DOXX_TOKEN]`, `primaryEnv: DOXX_TOKEN`)
- Codex skills name `DOXX_TOKEN` and the legacy `DOXXNET_TOKEN` fallback
- Every `<skill dir>/scripts/...` or `lib/...` a skill names ships with that skill
- `VERSION` matches plugin.json, marketplace.json, every OpenClaw frontmatter and the ClawHub bundle, and `CHANGELOG.md` has an entry for it
- No em dashes in `src/`, `api/`, the build scripts and the docs; no "VPN" in `src/` and `api/` except quoted user wording
- Code Mode scripts pass `bash -n` and `tests/run.sh` (which also checks, through a `curl` shim, that no token or `tunnel_token` is ever in a curl command line), and every shell script in the repo passes `shellcheck -x` (when installed)
- Every tracked script that is run directly is mode `100755` in the git index. With
  `core.fileMode=false` a new script is staged as `100644`: fix it with
  `git update-index --chmod=+x <path>` for the source and its generated copies

## Submitting a PR

1. Create a branch from `main`
2. Make your changes
3. Run `make check` and confirm 0 errors (CI runs `make check` and `make test` on Linux and macOS for every pull request)
4. Update `CHANGELOG.md` with your changes
5. Submit a pull request

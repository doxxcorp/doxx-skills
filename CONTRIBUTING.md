# Contributing to doxx-skills

## Prerequisites

- `bash`
- `python3`

## Adding a New Skill

1. Create a directory under `claude/skills/your-skill-name/`
2. Write a `SKILL.md` with YAML frontmatter:

```yaml
---
name: your-skill-name
description: "Short description (max 200 chars)"
argument-hint: "[action] [target]"
user-invocable: true
allowed-tools: Bash(curl *), Read, Write
---
```

3. The `name` field must match the directory name (lowercase, hyphenated).
4. Add evals in `claude/skills/your-skill-name/evals/evals.json`:

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
6. Register the skill in `claude/.claude-plugin/plugin.json` under the `commands` array.
7. If adding an OpenClaw version, create a matching `openclaw/skills/your-skill-name/SKILL.md`.

## Running Validation

```bash
make validate
```

This checks:

- Required files exist
- plugin.json is valid and references existing skills
- SKILL.md frontmatter has required fields (name, description)
- Skill names match directory names
- Internal markdown links resolve
- All API endpoints referenced in skills exist in `api/reference.md`
- Evals are present and well-formed
- OpenClaw skills have valid frontmatter and metadata

## Submitting a PR

1. Create a branch from `main`
2. Make your changes
3. Run `make validate` and confirm 0 errors
4. Update `CHANGELOG.md` with your changes
5. Submit a pull request

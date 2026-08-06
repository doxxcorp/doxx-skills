#!/usr/bin/env bash
set -euo pipefail

# Assemble the single-folder ClawHub variant of the doxxnet skill:
# the umbrella SKILL.md plus every module skill flattened into
# references/<name>.md, so one `clawhub skill publish` ships the full set.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/openclaw/skills"
DIST="$REPO_ROOT/dist/clawhub/doxxnet"

rm -rf "$DIST"
mkdir -p "$DIST/references"

python3 - "$SRC" "$DIST" <<'PY'
import re
import sys
from pathlib import Path

src = Path(sys.argv[1])
dist = Path(sys.argv[2])

FRONTMATTER = re.compile(r"\A---\n.*?\n---\n", re.DOTALL)


def frontmatter_field(text: str, field: str) -> str:
    match = re.search(rf"^{field}:\s*(.+)$", text, re.MULTILINE)
    if not match:
        raise SystemExit(f"missing '{field}' in frontmatter")
    return match.group(1).strip().strip('"')


modules = sorted(p for p in src.iterdir() if p.is_dir() and p.name != "doxxnet")

index_lines = []
for module in modules:
    text = (module / "SKILL.md").read_text()
    description = frontmatter_field(text, "description")
    body = FRONTMATTER.sub("", text)
    # $ARGUMENTS only means something in an invocable skill, not a reference file
    body = "\n".join(
        line for line in body.splitlines() if line.strip() != "User request: $ARGUMENTS"
    ).strip() + "\n"
    (dist / "references" / f"{module.name}.md").write_text(body)
    index_lines.append(f"- `references/{module.name}.md` — {description}")

umbrella = (src / "doxxnet" / "SKILL.md").read_text().rstrip()
section = (
    "\n\n## Reference files\n\n"
    "Before acting on one of these domains, read the matching reference file for the\n"
    "full endpoint snapshot (the live schema at https://config.doxx.net/ still wins on conflict):\n\n"
    + "\n".join(index_lines)
    + "\n"
)
(dist / "SKILL.md").write_text(umbrella + section)

print(f"assembled {dist.relative_to(dist.parents[2])} with {len(modules)} reference files")
PY

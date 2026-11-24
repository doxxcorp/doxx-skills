#!/usr/bin/env bash
set -euo pipefail

# Assemble the single-folder ClawHub variant of the doxxnet skill:
# the umbrella SKILL.md plus every module skill flattened into
# references/<name>.md, so one `clawhub skill publish` ships the full set.
# Every module's scripts/ are merged into the bundle's scripts/ (names must not
# collide) next to one lib/doxx.sh, so the `<skill dir>/scripts/...` lines in
# SKILL.md and references/*.md point at files inside the bundle. The build
# fails if any such path is missing.
#
# The output under clawhub/dist/ is checked in so the published artifact
# is reviewable at the source commit ClawHub provenance points to.
# `make clawhub-check` fails if it drifts from the sources.

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$REPO_ROOT/openclaw/skills"
DIST="$REPO_ROOT/clawhub/dist/doxxnet"

rm -rf "$DIST"
mkdir -p "$DIST/references"

python3 - "$SRC" "$DIST" <<'PY'
import re
import shutil
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

# Bundle every skill's scripts/ (umbrella included) plus the shared lib/.
script_owner = {}
for skill in sorted(p for p in src.iterdir() if p.is_dir()):
    scripts = skill / "scripts"
    if not scripts.is_dir():
        continue
    for script in sorted(scripts.iterdir()):
        if script.name == ".DS_Store":
            continue
        if script.name in script_owner:
            raise SystemExit(
                f"clawhub: scripts/{script.name} exists in both {script_owner[script.name]} and {skill.name}"
            )
        script_owner[script.name] = skill.name
        (dist / "scripts").mkdir(exist_ok=True)
        shutil.copy2(script, dist / "scripts" / script.name)
    lib = skill / "lib"
    if lib.is_dir() and not (dist / "lib").exists():
        shutil.copytree(lib, dist / "lib", ignore=shutil.ignore_patterns(".DS_Store"))

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
    index_lines.append(f"- `references/{module.name}.md`: {description}")

umbrella = (src / "doxxnet" / "SKILL.md").read_text().rstrip()
section = (
    "\n\n## Reference files\n\n"
    "Before acting on one of these domains, read the matching reference file for the\n"
    "full endpoint snapshot (the live schema at https://config.doxx.net/ still wins on conflict):\n\n"
    + "\n".join(index_lines)
    + "\n\n"
    "In the reference files too, `<skill dir>` means this skill's root directory (the one that\n"
    "holds this SKILL.md): every script they name is in its `scripts/` directory.\n"
)
(dist / "SKILL.md").write_text(umbrella + section)

# No file in the bundle may name a script or lib file the bundle does not ship.
missing = []
for md in sorted(dist.rglob("*.md")):
    for rel in sorted(set(re.findall(r"<skill dir>/((?:scripts|lib)/[A-Za-z0-9_.-]+)", md.read_text()))):
        if not (dist / rel).is_file():
            missing.append(f"{md.relative_to(dist)} -> {rel}")
if missing:
    raise SystemExit("clawhub: referenced files missing from the bundle:\n  " + "\n  ".join(missing))

print(f"assembled {dist.relative_to(dist.parents[2])} with {len(modules)} reference files")
PY

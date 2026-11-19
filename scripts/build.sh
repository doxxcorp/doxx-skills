#!/usr/bin/env bash
set -euo pipefail

# Generate the per-runtime skill trees from the single source under src/.
#
#   src/skills/<name>/body.md                -> body shared by every runtime
#   src/skills/<name>/frontmatter.claude.yml   -> claude/skills/<name>/SKILL.md frontmatter
#   src/skills/<name>/frontmatter.openclaw.yml -> openclaw/skills/<name>/SKILL.md frontmatter
#                                              (`{{version}}` is replaced with the VERSION file)
#   src/skills/<name>/evals.json             -> claude/skills/<name>/evals/evals.json
#   src/skills/<name>/scripts/               -> <runtime>/skills/<name>/scripts/ (all runtimes)
#   src/lib/doxx.sh                          -> <runtime>/skills/<name>/lib/doxx.sh, for every
#                                              skill that has scripts/ (they source ../lib/doxx.sh)
#                                              or whose text names `<skill dir>/lib/`
#   src/partials/<partial>.md                -> spliced in by a `<!-- include: <partial> -->` line
#
# Codex output (codex/skills/<name>/AGENTS.md) is the body alone, no frontmatter.
# Claude and OpenClaw output is: `---`, the frontmatter file verbatim, `---`,
# one blank line, then the body.
#
# Runtime-specific passages in body.md (and partials) are wrapped in block
# markers, each on its own line, no nesting:
#
#   <!-- runtime:claude -->           kept only for claude
#   <!-- runtime:claude,openclaw -->  kept for claude and openclaw
#   <!-- /runtime -->                 closes the block
#
# Includes are resolved first, then runtime blocks are filtered.
#
# The version is single-sourced in VERSION at the repo root. Frontmatter files
# say `version: {{version}}`; any other `version:` value is an error.
#
# Everything directly under claude/skills/, openclaw/skills/ and codex/skills/
# is generated and is DELETED on every run (after the whole stage built
# cleanly), so skills removed from src/ disappear from all three runtime trees.
# Do not keep anything else in those directories. Never hand-edit the
# generated files: edit src/ and run `make build`.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/src/skills"
PARTIALS="$REPO_ROOT/src/partials"
LIB="$REPO_ROOT/src/lib"
RUNTIMES=(claude openclaw codex)

die() { echo "build: $*" >&2; exit 1; }

[[ -d "$SRC" ]] || die "missing $SRC"
[[ -f "$REPO_ROOT/VERSION" ]] || die "missing $REPO_ROOT/VERSION"
VERSION="$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "VERSION must be MAJOR.MINOR.PATCH, got '$VERSION'"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Splice `<!-- include: name -->` lines with src/partials/name.md (recursive).
expand_includes() {
  awk -v partials="$PARTIALS" '
    function emit(file, depth,    line, name, path, rc) {
      if (depth > 10) { print "build: include depth exceeded in " file > "/dev/stderr"; exit 1 }
      while ((rc = (getline line < file)) > 0) {
        if (line ~ /<!--[ \t]*include/ && line !~ /^<!-- include: [A-Za-z0-9_.-]+ -->$/) {
          print "build: " file ": malformed include marker (must be the whole line `<!-- include: name -->`; check for CRLF line endings): " line > "/dev/stderr"
          exit 1
        }
        if (line ~ /^<!-- include: [A-Za-z0-9_.-]+ -->$/) {
          name = line
          sub(/^<!-- include: /, "", name)
          sub(/ -->$/, "", name)
          path = partials "/" name ".md"
          if ((getline probe < path) < 0) { print "build: missing partial " path " (from " file ")" > "/dev/stderr"; exit 1 }
          close(path)
          emit(path, depth + 1)
        } else {
          print line
        }
      }
      if (rc < 0) { print "build: cannot read " file > "/dev/stderr"; exit 1 }
      close(file)
    }
    BEGIN { emit(ARGV[1], 0); exit 0 }
  ' "$1"
}

# Keep shared lines plus the blocks that name the given runtime.
filter_runtime() {
  awk -v rt="$1" -v src="$2" '
    function bad(msg) { print "build: " src ":" NR ": " msg > "/dev/stderr"; failed = 1; exit 1 }
    /^<!-- runtime:[a-z,]+ -->$/ {
      if (inblock) bad("nested runtime block")
      list = $0
      sub(/^<!-- runtime:/, "", list)
      sub(/ -->$/, "", list)
      n = split(list, names, ",")
      keep = 0
      for (i = 1; i <= n; i++) {
        if (names[i] != "claude" && names[i] != "openclaw" && names[i] != "codex") bad("unknown runtime " names[i])
        if (names[i] == rt) keep = 1
      }
      inblock = 1
      next
    }
    /^<!-- \/runtime -->$/ {
      if (!inblock) bad("stray <!-- /runtime -->")
      inblock = 0
      next
    }
    /^[ \t]*<!--[ \t]*\/?runtime/ { bad("malformed runtime marker (must be the whole line; check for CRLF line endings): " $0) }
    !inblock || keep { print }
    END { if (!failed && inblock) { print "build: " src ": unclosed runtime block" > "/dev/stderr"; exit 1 } }
  '
}

# Frontmatter files are spliced between `---` lines verbatim, so they must end
# with a newline, use LF line endings, and take the version from VERSION.
check_frontmatter() {
  local fm="$1"
  [[ -f "$fm" ]] || die "missing $fm"
  [[ -s "$fm" ]] || die "$fm is empty"
  [[ -z "$(tail -c 1 "$fm")" ]] || die "$fm must end with a newline"
  ! grep -q $'\r' "$fm" || die "$fm has CRLF line endings"
  if grep -E '^version:' "$fm" | grep -vqxF 'version: {{version}}'; then
    die "$fm: write 'version: {{version}}' (the version comes from VERSION)"
  fi
}

with_frontmatter() {
  printf -- '---\n'
  sed "s/{{version}}/$VERSION/g" "$1"
  printf -- '---\n\n'
  cat
}

count=0
for skill_dir in "$SRC"/*/; do
  skill_dir="${skill_dir%/}"
  name="$(basename "$skill_dir")"
  body="$skill_dir/body.md"
  [[ -f "$body" ]] || die "missing $body"

  expanded="$STAGE/$name.expanded.md"
  expand_includes "$body" > "$expanded"

  for rt in "${RUNTIMES[@]}"; do
    out_dir="$STAGE/$rt/skills/$name"
    mkdir -p "$out_dir"
    case "$rt" in
      codex)
        filter_runtime "$rt" "src/skills/$name/body.md" < "$expanded" > "$out_dir/AGENTS.md"
        ;;
      *)
        check_frontmatter "$skill_dir/frontmatter.$rt.yml"
        filter_runtime "$rt" "src/skills/$name/body.md" < "$expanded" \
          | with_frontmatter "$skill_dir/frontmatter.$rt.yml" > "$out_dir/SKILL.md"
        ;;
    esac
    if [[ -d "$skill_dir/scripts" ]]; then
      cp -Rp "$skill_dir/scripts" "$out_dir/scripts"
      find "$out_dir/scripts" -name .DS_Store -delete
    fi
    if [[ -d "$skill_dir/scripts" ]] || grep -qF '<skill dir>/lib/' "$expanded"; then
      [[ -f "$LIB/doxx.sh" ]] || die "missing $LIB/doxx.sh (needed by src/skills/$name)"
      mkdir -p "$out_dir/lib"
      cp -p "$LIB/doxx.sh" "$out_dir/lib/doxx.sh"
    fi
  done

  if [[ -f "$skill_dir/evals.json" ]]; then
    mkdir -p "$STAGE/claude/skills/$name/evals"
    cat "$skill_dir/evals.json" > "$STAGE/claude/skills/$name/evals/evals.json"
  fi
  count=$((count + 1))
done

[[ $count -gt 0 ]] || die "no skills found under $SRC"

# Never wipe a runtime tree unless its replacement is fully staged.
for rt in "${RUNTIMES[@]}"; do
  staged="$(find "$STAGE/$rt/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
  [[ "$staged" -eq "$count" ]] || die "stage for $rt has $staged skill dirs, expected $count; nothing replaced"
done

# Every stage built cleanly: swap the generated skill dirs in.
for rt in "${RUNTIMES[@]}"; do
  root="$REPO_ROOT/$rt/skills"
  mkdir -p "$root"
  find "$root" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  mv "$STAGE/$rt/skills"/* "$root"/
done

echo "built $count skills for ${RUNTIMES[*]}"

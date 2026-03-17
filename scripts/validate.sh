#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0

pass() { printf "  \033[32m✓\033[0m %s\n" "$1"; }
fail() { printf "  \033[31m✗\033[0m %s\n" "$1"; ERRORS=$((ERRORS + 1)); }
section() { printf "\n\033[1m%s\033[0m\n" "$1"; }

# ─── Dependencies ─────────────────────────────────────────────────────────────

for cmd in python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: $cmd is required."
    exit 1
  fi
done

# ─── Structure ────────────────────────────────────────────────────────────────

section "Structure"

EXPECTED_FILES=(
  README.md
  LICENSE
  api/reference.md
  plugins/doxxnet/.claude-plugin/plugin.json
)

for f in "${EXPECTED_FILES[@]}"; do
  if [[ -f "$REPO_ROOT/$f" ]]; then
    pass "$f exists"
  else
    fail "$f missing"
  fi
done

# Check no empty markdown files
while IFS= read -r -d '' md; do
  rel="${md#"$REPO_ROOT/"}"
  if [[ ! -s "$md" ]]; then
    fail "$rel is empty"
  fi
done < <(find "$REPO_ROOT" -name '*.md' -not -path '*/.git/*' -not -path '*/.venv/*' -not -path '*/node_modules/*' -print0)

# ─── plugin.json ──────────────────────────────────────────────────────────────

section "plugin.json"

PLUGIN="$REPO_ROOT/plugins/doxxnet/.claude-plugin/plugin.json"

if python3 -c "import json; json.load(open('$PLUGIN'))" 2>/dev/null; then
  pass "valid JSON"
else
  fail "invalid JSON"
fi

for field in name version description; do
  if python3 -c "import json; d=json.load(open('$PLUGIN')); assert '$field' in d" 2>/dev/null; then
    pass "has .$field"
  else
    fail "missing .$field"
  fi
done

# Check that every command path in marketplace.json has a SKILL.md
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"
while IFS= read -r cmd_path; do
  # Strip leading ./ if present
  cmd_path="${cmd_path#./}"
  # Strip trailing / if present
  cmd_path="${cmd_path%/}"
  skill_md="$REPO_ROOT/$cmd_path/SKILL.md"
  if [[ -f "$skill_md" ]]; then
    pass "marketplace.json → $cmd_path/SKILL.md exists"
  else
    fail "marketplace.json → $cmd_path/SKILL.md not found"
  fi
done < <(python3 -c "import json; m=json.load(open('$MARKETPLACE')); [print(c) for p in m['plugins'] for c in p.get('commands', [])]")

# ─── SKILL.md frontmatter ────────────────────────────────────────────────────

section "Skill frontmatter"

SKILLS_DIR="$REPO_ROOT/claude/skills"

for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name="$(basename "$skill_dir")"
  skill_md="$skill_dir/SKILL.md"

  if [[ ! -f "$skill_md" ]]; then
    fail "$skill_name: missing SKILL.md"
    continue
  fi

  # Check starts with ---
  if head -1 "$skill_md" | grep -q '^---$'; then
    pass "$skill_name: has frontmatter"
  else
    fail "$skill_name: missing frontmatter (must start with ---)"
    continue
  fi

  # Extract frontmatter (between first and second ---)
  frontmatter=$(sed -n '2,/^---$/p' "$skill_md" | sed '$d')

  # Parse fields with grep (portable, no yq dependency)
  fm_name=$(echo "$frontmatter" | grep '^name:' | sed 's/^name: *//' || true)
  fm_desc=$(echo "$frontmatter" | grep '^description:' | sed 's/^description: *//' || true)

  if [[ -n "$fm_name" ]]; then
    pass "$skill_name: has name ($fm_name)"
  else
    fail "$skill_name: missing name field"
  fi

  if [[ -n "$fm_desc" ]]; then
    desc_len=${#fm_desc}
    if [[ $desc_len -le 200 ]]; then
      pass "$skill_name: description ok ($desc_len chars)"
    else
      fail "$skill_name: description too long ($desc_len > 200 chars)"
    fi
  else
    fail "$skill_name: missing description field"
  fi

  # Check name matches directory
  if [[ "$fm_name" == "$skill_name" ]]; then
    pass "$skill_name: name matches directory"
  else
    fail "$skill_name: name '$fm_name' doesn't match directory"
  fi
done

# ─── Internal links ──────────────────────────────────────────────────────────

section "Internal links"

check_links_in() {
  local file="$1"
  local rel="${file#"$REPO_ROOT/"}"
  local dir
  dir="$(dirname "$file")"

  # Extract markdown link hrefs: [text](href)
  local hrefs
  hrefs=$(grep -o '\[[^]]*\]([^)]*)' "$file" | sed 's/.*\](\(.*\))/\1/' || true)
  [[ -z "$hrefs" ]] && return 0

  while IFS= read -r href; do
    # Skip external URLs, anchors, variables
    case "$href" in
      http://*|https://*|mailto:*|\#*|\$*) continue ;;
    esac

    # Strip anchor
    path_part="${href%%#*}"
    [[ -z "$path_part" ]] && continue

    target="$dir/$path_part"
    if [[ -e "$target" ]]; then
      pass "$rel → $href"
    else
      fail "$rel → $href (not found)"
    fi
  done <<< "$hrefs"
}

for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
  [[ -f "$skill_md" ]] && check_links_in "$skill_md"
done

# ─── API consistency ─────────────────────────────────────────────────────────

section "API consistency"

REFERENCE="$REPO_ROOT/api/reference.md"

# Extract endpoint names from patterns like endpoint=1, 'endpoint': '1', and /api/stats/endpoint
ref_endpoints=$(grep -oE "'[a-z_]+': *'1'" "$REFERENCE" 2>/dev/null | sed "s/'//g; s/: *1//; s/ //g" | sort -u || true)
ref_endpoints_curl=$(grep -o '"[a-z_]*=1' "$REFERENCE" 2>/dev/null | sed 's/^"//; s/=1$//' | sort -u || true)
ref_endpoints_stats=$(grep -oE '/api/stats/[a-z_]+' "$REFERENCE" 2>/dev/null | sed 's|.*/||' | sort -u || true)
ref_endpoints=$(printf "%s\n%s\n%s" "$ref_endpoints" "$ref_endpoints_curl" "$ref_endpoints_stats" | sort -u)

for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
  rel="${skill_md#"$REPO_ROOT/"}"
  # Match endpoint=1 patterns in curl examples and backtick endpoint names in lists
  skill_endpoints_curl=$(grep -o '"[a-z_]*=1' "$skill_md" 2>/dev/null | sed 's/^"//; s/=1$//' | sort -u || true)
  skill_endpoints_list=$(grep -oE '^\- `[a-z_]+`' "$skill_md" 2>/dev/null | sed 's/^- `//; s/`$//' | sort -u || true)
  all_endpoints=$(printf "%s\n%s" "$skill_endpoints_curl" "$skill_endpoints_list" | sort -u)

  for ep in $all_endpoints; do
    [[ -z "$ep" ]] && continue
    case "$ep" in
      enabled|apply_to_all) continue ;;
    esac

    if echo "$ref_endpoints" | grep -qx "$ep"; then
      pass "$rel: $ep in reference"
    else
      fail "$rel: $ep not found in api/reference.md"
    fi
  done
done

# ─── Evals ───────────────────────────────────────────────────────────────────

section "Evals"

for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name="$(basename "$skill_dir")"
  evals_file="$skill_dir/evals/evals.json"

  if [[ -f "$evals_file" ]]; then
    if python3 -c "import json; json.load(open('$evals_file'))" 2>/dev/null; then
      pass "$skill_name: evals.json valid"

      eval_count=$(python3 -c "import json; print(len(json.load(open('$evals_file'))['evals']))")
      if [[ "$eval_count" -gt 0 ]]; then
        pass "$skill_name: $eval_count eval(s)"
      else
        fail "$skill_name: evals array is empty"
      fi

      missing=$(python3 -c "
import json
evals = json.load(open('$evals_file'))['evals']
missing = [e.get('id', 'unknown') for e in evals if not e.get('prompt') or not e.get('expectations')]
print(' '.join(missing))
")
      if [[ -z "$missing" || "$missing" == " " ]]; then
        pass "$skill_name: all evals have prompt + expectations"
      else
        fail "$skill_name: eval(s) missing prompt or expectations: $missing"
      fi
    else
      fail "$skill_name: evals.json invalid JSON"
    fi
  else
    fail "$skill_name: missing evals/evals.json"
  fi
done

# ─── OpenClaw skills ─────────────────────────────────────────────────────────

OPENCLAW_DIR="$REPO_ROOT/openclaw/skills"

if [[ -d "$OPENCLAW_DIR" ]]; then
  section "OpenClaw skills"

  for skill_dir in "$OPENCLAW_DIR"/*/; do
    skill_name="$(basename "$skill_dir")"
    skill_md="$skill_dir/SKILL.md"

    if [[ ! -f "$skill_md" ]]; then
      fail "openclaw/$skill_name: missing SKILL.md"
      continue
    fi

    # Check starts with ---
    if head -1 "$skill_md" | grep -q '^---$'; then
      pass "openclaw/$skill_name: has frontmatter"
    else
      fail "openclaw/$skill_name: missing frontmatter (must start with ---)"
      continue
    fi

    # Extract frontmatter
    frontmatter=$(sed -n '2,/^---$/p' "$skill_md" | sed '$d')

    fm_name=$(echo "$frontmatter" | grep '^name:' | sed 's/^name: *//' || true)
    fm_desc=$(echo "$frontmatter" | grep '^description:' | sed 's/^description: *//' || true)
    fm_meta=$(echo "$frontmatter" | grep '^metadata\.openclaw:' | sed 's/^metadata\.openclaw: *//' || true)

    if [[ -n "$fm_name" ]]; then
      pass "openclaw/$skill_name: has name ($fm_name)"
    else
      fail "openclaw/$skill_name: missing name field"
    fi

    if [[ -n "$fm_desc" ]]; then
      desc_len=${#fm_desc}
      if [[ $desc_len -le 200 ]]; then
        pass "openclaw/$skill_name: description ok ($desc_len chars)"
      else
        fail "openclaw/$skill_name: description too long ($desc_len > 200 chars)"
      fi
    else
      fail "openclaw/$skill_name: missing description field"
    fi

    # Check name matches directory
    if [[ "$fm_name" == "$skill_name" ]]; then
      pass "openclaw/$skill_name: name matches directory"
    else
      fail "openclaw/$skill_name: name '$fm_name' doesn't match directory"
    fi

    # Check metadata.openclaw is present and valid JSON
    if [[ -n "$fm_meta" ]]; then
      if python3 -c "import json; json.loads('$fm_meta')" 2>/dev/null; then
        pass "openclaw/$skill_name: metadata.openclaw valid JSON"
      else
        fail "openclaw/$skill_name: metadata.openclaw invalid JSON"
      fi
    else
      fail "openclaw/$skill_name: missing metadata.openclaw"
    fi

    # API consistency for OpenClaw skills
    skill_endpoints_curl=$(grep -o '"[a-z_]*=1' "$skill_md" 2>/dev/null | sed 's/^"//; s/=1$//' | sort -u || true)
    skill_endpoints_list=$(grep -oE '^\- `[a-z_]+`' "$skill_md" 2>/dev/null | sed 's/^- `//; s/`$//' | sort -u || true)
    oc_all_endpoints=$(printf "%s\n%s" "$skill_endpoints_curl" "$skill_endpoints_list" | sort -u)

    for ep in $oc_all_endpoints; do
      [[ -z "$ep" ]] && continue
      case "$ep" in
        enabled|apply_to_all) continue ;;
      esac

      if echo "$ref_endpoints" | grep -qx "$ep"; then
        pass "openclaw/$skill_name: $ep in reference"
      else
        fail "openclaw/$skill_name: $ep not found in api/reference.md"
      fi
    done
  done

  # Check OpenClaw skill count matches Claude skill count
  claude_count=$(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
  openclaw_count=$(find "$OPENCLAW_DIR" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
  if [[ "$claude_count" -eq "$openclaw_count" ]]; then
    pass "openclaw skill count ($openclaw_count) matches claude ($claude_count)"
  else
    fail "openclaw skill count ($openclaw_count) != claude ($claude_count)"
  fi
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
if [[ $ERRORS -eq 0 ]]; then
  printf "\033[32mAll checks passed.\033[0m\n"
else
  printf "\033[31m%d check(s) failed.\033[0m\n" "$ERRORS"
  exit 1
fi

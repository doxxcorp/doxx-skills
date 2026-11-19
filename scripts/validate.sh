#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0

pass() { printf "  \033[32m✓\033[0m %s\n" "$1"; }
fail() { printf "  \033[31m✗\033[0m %s\n" "$1"; ERRORS=$((ERRORS + 1)); }
section() { printf "\n\033[1m%s\033[0m\n" "$1"; }

# ─── Dependencies ─────────────────────────────────────────────────────────────

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required."
  exit 1
fi

# The shellcheck pass and the Code Mode tests (jq, curl) are optional on a
# laptop, where a missing tool is skipped with a warning. In CI (GitHub Actions
# sets CI=true) a missing tool is a failure, so a check cannot pass by not
# running.
IN_CI=false
[[ "${CI:-}" == "true" ]] && IN_CI=true
have() { command -v "$1" >/dev/null 2>&1; }
missing_tool() { # TOOL WHAT
  if $IN_CI; then
    fail "$1 is not installed, so $2 did not run (required in CI)"
  else
    printf "  \033[33m!\033[0m %s skipped: %s is not installed (CI fails on this)\n" "$2" "$1"
  fi
}

# ─── Structure ────────────────────────────────────────────────────────────────

section "Structure"

EXPECTED_FILES=(
  README.md
  LICENSE
  api/reference.md
  .claude-plugin/plugin.json
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

PLUGIN="$REPO_ROOT/.claude-plugin/plugin.json"

if python3 -c "import json; json.load(open('$PLUGIN'))" 2>/dev/null; then
  pass "valid JSON"
else
  fail "invalid JSON"
fi

for field in name version description skills; do
  if python3 -c "import json; d=json.load(open('$PLUGIN')); assert '$field' in d" 2>/dev/null; then
    pass "has .$field"
  else
    fail "missing .$field"
  fi
done

# Claude Code loads only the skills listed here (each entry is a skill
# directory holding SKILL.md). `commands` would replace that path and load
# the two listed skills a second time, so it must stay absent.
if python3 -c "import json; assert 'commands' not in json.load(open('$PLUGIN'))" 2>/dev/null; then
  pass "no .commands (skills are listed under .skills)"
else
  fail "plugin.json has .commands: list skill directories under .skills instead"
fi

# Every skill path in plugin.json has a SKILL.md
while IFS= read -r skill_path; do
  skill_path="${skill_path#./}"
  skill_path="${skill_path%/}"
  skill_md="$REPO_ROOT/$skill_path/SKILL.md"
  if [[ -f "$skill_md" ]]; then
    pass "plugin.json → $skill_path/SKILL.md exists"
  else
    fail "plugin.json → $skill_path/SKILL.md not found"
  fi
done < <(python3 -c "import json; [print(c) for c in json.load(open('$PLUGIN')).get('skills', [])]")

# ...and every skill in src/skills is listed, so Claude Code users get all of them.
plugin_skills="$(python3 -c "import json; [print(c.rstrip('/').split('/')[-1]) for c in json.load(open('$PLUGIN')).get('skills', [])]" | sort)"
src_skills="$(find "$REPO_ROOT/src/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)"
if [[ "$plugin_skills" == "$src_skills" ]]; then
  pass "plugin.json .skills lists every skill in src/skills"
else
  fail "plugin.json .skills differs from src/skills: $(diff <(echo "$src_skills") <(echo "$plugin_skills") | grep '^[<>]' | tr '\n' ' ')"
fi

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
# Every documented endpoint has a "### name" heading (api-drift reads the same
# headings); the example patterns above are kept as a second source.
ref_endpoints_headings=$(sed -n 's/^### \([a-z_][a-z0-9_]*\)$/\1/p' "$REFERENCE" | sort -u)
ref_endpoints=$(printf "%s\n%s\n%s\n%s" "$ref_endpoints" "$ref_endpoints_curl" "$ref_endpoints_stats" "$ref_endpoints_headings" | sort -u)

for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
  rel="${skill_md#"$REPO_ROOT/"}"
  # Match endpoint=1 patterns in curl examples and backtick endpoint names in lists
  skill_endpoints_curl=$(grep -o '"[a-z_]*=1' "$skill_md" 2>/dev/null | sed 's/^"//; s/=1$//' | sort -u || true)
  # shellcheck disable=SC2016 # the backticks are literal Markdown
  skill_endpoints_list=$(grep -oE '^\- `[a-z_]+`' "$skill_md" 2>/dev/null | sed 's/^- `//; s/`$//' | sort -u || true)
  all_endpoints=$(printf "%s\n%s" "$skill_endpoints_curl" "$skill_endpoints_list" | sort -u)

  for ep in $all_endpoints; do
    [[ -z "$ep" ]] && continue
    case "$ep" in
      enabled|apply_to_all) continue ;;
    esac

    if grep -qx -- "$ep" <<< "$ref_endpoints"; then
      pass "$rel: $ep in reference"
    else
      fail "$rel: $ep not found in api/reference.md"
    fi
  done
done

# Public text names only endpoints of the public API. A form that starts with
# `"<name>=1` (a curl call) anywhere in the sources, docs, evals or generated
# trees must name a `### <name>` heading of api/reference.md, which
# `make api-drift` keeps equal to the live manifest.
PUBLIC_TEXT=(src api scripts tests README.md CONTRIBUTING.md CHANGELOG.md openclaw codex claude clawhub .github .claude-plugin)
ref_headings="$(grep -E '^### [a-z0-9_]+$' "$REFERENCE" | sed 's/^### //' | sort -u)"
form_eps="$(cd "$REPO_ROOT" && grep -rhoE '(^|[^a-z0-9_])"[a-z0-9_]+=1' "${PUBLIC_TEXT[@]}" 2>/dev/null | sed -E 's/.*"//; s/=1$//' | sort -u || true)"
unknown_eps="$(comm -23 <(printf '%s\n' "$form_eps" | grep -vx 'endpoint' || true) <(printf '%s\n' "$ref_headings"))"
if [[ -z "$unknown_eps" ]]; then
  pass "every \"<endpoint>=1 form in public text is a reference heading"
else
  fail "\"<endpoint>=1 forms that are not reference headings (not in the public manifest?): $(printf '%s' "$unknown_eps" | tr '\n' ' ')"
fi

# Endpoints the manifest hides are never named in public text, not even in a
# "does not call ..." line. The list holds SHA-256 prefixes, not the names, so
# this file does not name them either. Every snake_case word in the public
# text is hashed and compared.
HIDDEN_EP_HASHES="be3c2ab9f7365f0b 9bc9d13b1a10a35b 73a822c49f0551a7 99b8bbf58faee615 f39a3a12754fcba9 966d65c82b205273 2b849e2bb0d71673 3a3bc3fe8cf5df43 889135db2b14f0a5 b3a974e3a1ac1f5d"
hidden_hits="$(cd "$REPO_ROOT" && python3 - "$HIDDEN_EP_HASHES" "${PUBLIC_TEXT[@]}" <<'PY'
import hashlib, os, re, sys
hashes = set(sys.argv[1].split())
word = re.compile(r"[a-z0-9]+(?:_[a-z0-9]+)+")
for root in sys.argv[2:]:
    paths = [root] if os.path.isfile(root) else [os.path.join(d, f) for d, _, fs in os.walk(root) for f in fs]
    for path in sorted(paths):
        try:
            text = open(path, encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            continue
        for n, line in enumerate(text.splitlines(), 1):
            if any(hashlib.sha256(w.encode()).hexdigest()[:16] in hashes for w in set(word.findall(line))):
                print(f"{path}:{n}")
PY
)"
if [[ -z "$hidden_hits" ]]; then
  pass "no endpoint outside the public manifest is named in public text"
else
  fail "public text names an endpoint the manifest hides (say what the skill does instead):"
  printf '%s\n' "$hidden_hits" | sed 's/^/      /'
fi

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

    # Check nested metadata.openclaw block (OpenClaw 2.0 skill schema):
    # metadata: -> openclaw: -> requires: {env, bins}, primaryEnv. See
    # docs.openclaw.ai/clawhub/skill-format. The legacy dotted top-level
    # key "metadata.openclaw:" is not the path the OpenClaw flattener reads.
    if echo "$frontmatter" | python3 -c '
import sys, re
fm = sys.stdin.read()
def has(p): return re.search(p, fm, re.M)
ok = (has(r"^metadata:\s*$")
      and has(r"^\s+openclaw:\s*$")
      and has(r"^\s+requires:\s*$")
      and has(r"^\s+env:\s*\[\s*DOXX_TOKEN\s*\]\s*$")
      and has(r"^\s+bins:\s*\[[^]]*\]\s*$")
      and has(r"^\s+primaryEnv:\s*DOXX_TOKEN\s*$"))
sys.exit(0 if ok else 1)
'; then
      pass "openclaw/$skill_name: metadata.openclaw nested block ok"
    else
      fail "openclaw/$skill_name: metadata.openclaw block missing or malformed (need requires.env [DOXX_TOKEN], requires.bins, primaryEnv DOXX_TOKEN)"
    fi

    # API consistency for OpenClaw skills
    skill_endpoints_curl=$(grep -o '"[a-z_]*=1' "$skill_md" 2>/dev/null | sed 's/^"//; s/=1$//' | sort -u || true)
    # shellcheck disable=SC2016 # the backticks are literal Markdown
    skill_endpoints_list=$(grep -oE '^\- `[a-z_]+`' "$skill_md" 2>/dev/null | sed 's/^- `//; s/`$//' | sort -u || true)
    oc_all_endpoints=$(printf "%s\n%s" "$skill_endpoints_curl" "$skill_endpoints_list" | sort -u)

    for ep in $oc_all_endpoints; do
      [[ -z "$ep" ]] && continue
      case "$ep" in
        enabled|apply_to_all) continue ;;
      esac

      if grep -qx -- "$ep" <<< "$ref_endpoints"; then
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

# ─── Codex agent skills ───────────────────────────────────────────────────────

CODEX_DIR="$REPO_ROOT/codex/skills"

if [[ -d "$CODEX_DIR" ]]; then
  section "Codex agent skills"

  for skill_dir in "$CODEX_DIR"/*/; do
    skill_name="$(basename "$skill_dir")"
    agents_md="$skill_dir/AGENTS.md"

    if [[ ! -f "$agents_md" ]]; then
      fail "codex/$skill_name: missing AGENTS.md"
      continue
    fi

    pass "codex/$skill_name: AGENTS.md exists"

    # Check AGENTS.md has no frontmatter (should NOT start with ---)
    if head -1 "$agents_md" | grep -q '^---$'; then
      fail "codex/$skill_name: AGENTS.md should not have YAML frontmatter"
    else
      pass "codex/$skill_name: no frontmatter (correct)"
    fi

    # Token sources: DOXX_TOKEN first, legacy DOXXNET_TOKEN as the fallback
    if grep -q 'DOXX_TOKEN' "$agents_md" && grep -q 'DOXXNET_TOKEN' "$agents_md"; then
      pass "codex/$skill_name: references DOXX_TOKEN (and the DOXXNET_TOKEN fallback)"
    else
      fail "codex/$skill_name: missing DOXX_TOKEN or the DOXXNET_TOKEN fallback"
    fi

    # API consistency for Codex skills
    skill_endpoints_curl=$(grep -o '"[a-z_]*=1' "$agents_md" 2>/dev/null | sed 's/^"//; s/=1$//' | sort -u || true)
    # shellcheck disable=SC2016 # the backticks are literal Markdown
    skill_endpoints_list=$(grep -oE '^\- `[a-z_]+`' "$agents_md" 2>/dev/null | sed 's/^- `//; s/`$//' | sort -u || true)
    codex_all_endpoints=$(printf "%s\n%s" "$skill_endpoints_curl" "$skill_endpoints_list" | sort -u)

    for ep in $codex_all_endpoints; do
      [[ -z "$ep" ]] && continue
      case "$ep" in
        enabled|apply_to_all) continue ;;
      esac

      if grep -qx -- "$ep" <<< "$ref_endpoints"; then
        pass "codex/$skill_name: $ep in reference"
      else
        fail "codex/$skill_name: $ep not found in api/reference.md"
      fi
    done
  done

  # Check Codex skill count matches Claude skill count
  claude_count=$(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
  codex_count=$(find "$CODEX_DIR" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
  if [[ "$claude_count" -eq "$codex_count" ]]; then
    pass "codex skill count ($codex_count) matches claude ($claude_count)"
  else
    fail "codex skill count ($codex_count) != claude ($claude_count)"
  fi
fi

# ─── Source vs generated ─────────────────────────────────────────────────────

SRC_DIR="$REPO_ROOT/src/skills"

section "Source vs generated"

if [[ -d "$SRC_DIR" ]]; then
  src_names=$(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
  for gen_root in claude/skills openclaw/skills codex/skills; do
    gen_names=$(find "$REPO_ROOT/$gen_root" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort)
    if [[ "$src_names" == "$gen_names" ]]; then
      pass "src/skills names match $gen_root"
    else
      fail "src/skills names differ from $gen_root (run 'make build'): $(diff <(echo "$src_names") <(echo "$gen_names") | grep '^[<>]' | tr '\n' ' ')"
    fi
  done
else
  fail "src/skills missing"
fi

# ─── Bundled files ───────────────────────────────────────────────────────────

section "Bundled files"

# Every `<skill dir>/scripts/x` or `<skill dir>/lib/x` a skill names must ship
# in that skill's own directory, in every runtime tree. (The ClawHub bundle is
# checked by clawhub/scripts/build.sh.)
bundle_refs=0
for skill_file in "$REPO_ROOT"/claude/skills/*/SKILL.md "$REPO_ROOT"/openclaw/skills/*/SKILL.md "$REPO_ROOT"/codex/skills/*/AGENTS.md; do
  [[ -f "$skill_file" ]] || continue
  rel="${skill_file#"$REPO_ROOT/"}"
  dir="$(dirname "$skill_file")"
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    bundle_refs=$((bundle_refs + 1))
    if [[ -f "$dir/$ref" ]]; then
      pass "$rel → $ref"
    else
      fail "$rel → $ref (not shipped in $(basename "$dir")/)"
    fi
  done < <(grep -oE '<skill dir>/(scripts|lib)/[A-Za-z0-9_.-]+' "$skill_file" | sed 's|^<skill dir>/||' | sort -u || true)
done
[[ $bundle_refs -gt 0 ]] && pass "$bundle_refs bundled file reference(s) checked"

# ─── Version ─────────────────────────────────────────────────────────────────

section "Version"

VERSION_FILE="$REPO_ROOT/VERSION"
version="$(tr -d '[:space:]' < "$VERSION_FILE" 2>/dev/null || true)"
if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  pass "VERSION is $version"
else
  fail "VERSION missing or not MAJOR.MINOR.PATCH ('$version')"
fi

check_version() {
  local label="$1" got="$2"
  if [[ "$got" == "$version" ]]; then
    pass "$label: $got"
  else
    fail "$label: '$got' != VERSION '$version'"
  fi
}

check_version ".claude-plugin/plugin.json .version" \
  "$(python3 -c "import json; print(json.load(open('$PLUGIN'))['version'])" 2>/dev/null || true)"
check_version ".claude-plugin/marketplace.json .plugins[0].version" \
  "$(python3 -c "import json; print(json.load(open('$REPO_ROOT/.claude-plugin/marketplace.json'))['plugins'][0]['version'])" 2>/dev/null || true)"
for skill_md in "$REPO_ROOT"/openclaw/skills/*/SKILL.md "$REPO_ROOT"/clawhub/dist/*/SKILL.md; do
  [[ -f "$skill_md" ]] || continue
  check_version "${skill_md#"$REPO_ROOT/"} version" \
    "$(sed -n '2,/^---$/p' "$skill_md" | sed -n 's/^version: *//p' | head -1)"
done
if grep -qx "## $version" "$REPO_ROOT/CHANGELOG.md"; then
  pass "CHANGELOG.md has a '## $version' entry"
else
  fail "CHANGELOG.md has no '## $version' entry"
fi

# ─── Prose rules ─────────────────────────────────────────────────────────────

section "Prose rules"

# No em dashes (U+2014) in sources, docs and build scripts.
EM_DASH=$'\xe2\x80\x94'
PROSE_PATHS=(src api scripts clawhub/scripts README.md CONTRIBUTING.md CHANGELOG.md openclaw/README.md codex/README.md)
em_hits="$(cd "$REPO_ROOT" && grep -rnF "$EM_DASH" "${PROSE_PATHS[@]}" 2>/dev/null || true)"
if [[ -z "$em_hits" ]]; then
  pass "no em dashes in ${PROSE_PATHS[*]}"
else
  fail "em dashes found (use a colon, a period or a comma):"
  printf '%s\n' "$em_hits" | sed 's/^/      /'
fi

# The product is never called a "VPN". Allowed: lines that quote what users
# say: eval prompts, the quoted word "VPN", and eval expectations about the word.
VPN_ALLOW='"prompt":|"VPN"|the word VPN'
vpn_hits="$(cd "$REPO_ROOT" && grep -rnwE 'VPN' src api 2>/dev/null | grep -vE "$VPN_ALLOW" || true)"
if [[ -z "$vpn_hits" ]]; then
  pass "no 'VPN' in src/ and api/ outside quoted user wording"
else
  fail "'VPN' used in prose (say private network, network or tunnel):"
  printf '%s\n' "$vpn_hits" | sed 's/^/      /'
fi

# ─── Code Mode scripts ───────────────────────────────────────────────────────

section "Code Mode scripts"

GENERATED_DIRS=("$REPO_ROOT/claude/skills" "$REPO_ROOT/openclaw/skills" "$REPO_ROOT/codex/skills" "$REPO_ROOT/clawhub/dist")

script_count=0
while IFS= read -r -d '' script; do
  rel="${script#"$REPO_ROOT/"}"
  script_count=$((script_count + 1))
  if bash -n "$script" 2>/dev/null; then
    pass "$rel: bash -n"
  else
    fail "$rel: bash -n failed"
  fi
  case "$rel" in
    */scripts/*)
      lib="$(dirname "$(dirname "$script")")/lib/doxx.sh"
      if [[ -f "$lib" ]]; then
        pass "$rel: lib/doxx.sh present"
      else
        fail "$rel: lib/doxx.sh missing next to scripts/ (run 'make build')"
      fi
      if [[ -x "$script" ]]; then
        pass "$rel: executable"
      else
        fail "$rel: not executable"
      fi
      ;;
  esac
done < <(find "${GENERATED_DIRS[@]}" -type f -name '*.sh' \( -path '*/scripts/*' -o -path '*/lib/*' \) -print0 2>/dev/null)

if [[ $script_count -gt 0 ]]; then
  pass "$script_count generated script files checked"
fi

# The exec bit that ships is the one in the git index, not the one on disk: with
# core.fileMode=false a checkout can show +x while the commit still says 100644.
# Every tracked script that is run directly must be 100755. lib/doxx.sh is only
# ever sourced, so it is not in this list.
if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exec_pathspecs=(
    'scripts/*.sh' 'tests/*.sh' 'clawhub/scripts/*.sh'
    'src/skills/*/scripts/*.sh'
    'claude/skills/*/scripts/*.sh' 'openclaw/skills/*/scripts/*.sh'
    'codex/skills/*/scripts/*.sh' 'clawhub/dist/*/scripts/*.sh'
  )
  bad_modes="$(git -C "$REPO_ROOT" ls-files -s -- "${exec_pathspecs[@]}" | awk '$1 != "100755" { print $4 " (" $1 ")" }')"
  exec_count="$(git -C "$REPO_ROOT" ls-files -s -- "${exec_pathspecs[@]}" | wc -l | tr -d ' ')"
  if [[ -z "$bad_modes" ]]; then
    pass "$exec_count tracked scripts are 100755 in the git index"
  else
    fail "tracked scripts not executable in the git index (git update-index --chmod=+x <path>):"
    printf '%s\n' "$bad_modes" | sed 's/^/      /'
  fi
else
  printf "  \033[33m!\033[0m git index mode check skipped: not a git checkout\n"
fi

# ─── shellcheck ──────────────────────────────────────────────────────────────

section "shellcheck"

if have shellcheck; then
  sc_count=0
  sc_bad=0
  while IFS= read -r -d '' script; do
    rel="${script#"$REPO_ROOT/"}"
    sc_count=$((sc_count + 1))
    # Run from the repo root so `source-path=SCRIPTDIR` directives resolve the
    # same way here and in CI.
    if ! (cd "$REPO_ROOT" && shellcheck -x "$rel" >/dev/null 2>&1); then
      fail "$rel: shellcheck (run: shellcheck -x $rel)"
      sc_bad=$((sc_bad + 1))
    fi
  done < <(find "$REPO_ROOT/scripts" "$REPO_ROOT/tests" "$REPO_ROOT/clawhub/scripts" "$REPO_ROOT/src" "${GENERATED_DIRS[@]}" -type f -name '*.sh' -print0 2>/dev/null)
  if [[ $sc_bad -eq 0 ]]; then
    pass "shellcheck -x clean on $sc_count shell files"
  fi
else
  missing_tool shellcheck "shellcheck"
fi

# ─── Code Mode tests ─────────────────────────────────────────────────────────

section "Code Mode tests"

if have jq && have curl; then
  if test_out="$("$REPO_ROOT/tests/run.sh" 2>&1)"; then
    pass "tests/run.sh: $(printf '%s\n' "$test_out" | tail -1)"
  else
    fail "tests/run.sh failed:"
    printf '%s\n' "$test_out" | grep -E 'FAIL|tests:' || printf '%s\n' "$test_out" | tail -20
  fi
else
  have jq || missing_tool jq "tests/run.sh"
  have curl || missing_tool curl "tests/run.sh"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
if [[ $ERRORS -eq 0 ]]; then
  printf "\033[32mAll checks passed.\033[0m\n"
else
  printf "\033[31m%d check(s) failed.\033[0m\n" "$ERRORS"
  exit 1
fi

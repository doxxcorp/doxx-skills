#!/usr/bin/env bash
set -euo pipefail

# Compare the Config API endpoints in the live manifest with the endpoints
# documented in api/reference.md (one `### <endpoint>` heading each).
#
#   scripts/api-drift.sh                   fetch https://config.doxx.net/ (network, GET, no token)
#   scripts/api-drift.sh --manifest FILE   read a saved manifest instead (offline)
#
# Endpoints documented on purpose without a manifest entry (curl-only and
# handler-only ones) are listed in api/drift-allowlist.txt.
# Exit 0: no drift. Exit 1: drift. Exit 2: usage or fetch error.
# Not part of `make validate`, which stays offline: run `make api-drift`.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REFERENCE="$REPO_ROOT/api/reference.md"
ALLOWLIST="$REPO_ROOT/api/drift-allowlist.txt"
URL="https://config.doxx.net/"
MANIFEST=""

usage() { sed -n '4,13p' "$0" | sed 's/^# \{0,1\}//'; }
die() { echo "api-drift: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest) [[ $# -ge 2 ]] || die "--manifest needs a FILE"; MANIFEST="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

for cmd in jq curl; do
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"
done
[[ -f "$REFERENCE" ]] || die "missing $REFERENCE"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ -n "$MANIFEST" ]]; then
  [[ -f "$MANIFEST" ]] || die "no such manifest file: $MANIFEST"
  cp "$MANIFEST" "$WORK/manifest.json"
  source_label="$MANIFEST"
else
  # A GET to the root returns the manifest; no token is sent.
  curl -sS --fail --max-time 30 "$URL" -o "$WORK/manifest.json" \
    || die "could not fetch $URL"
  source_label="$URL"
fi

jq -r '.endpoints | to_entries[] | .value[] | .endpoint' "$WORK/manifest.json" 2>/dev/null \
  | sort -u > "$WORK/manifest.txt" || die "$source_label: no .endpoints groups (not a manifest?)"
[[ -s "$WORK/manifest.txt" ]] || die "$source_label: no endpoints found"

grep -E '^### [a-z0-9_]+$' "$REFERENCE" | sed 's/^### //' | sort -u > "$WORK/reference.txt"

if [[ -f "$ALLOWLIST" ]]; then
  sed 's/#.*//' "$ALLOWLIST" | tr -s ' \t' '\n' | grep -E '^[a-z0-9_]+$' | sort -u > "$WORK/allow.txt" || true
else
  : > "$WORK/allow.txt"
fi

missing="$(comm -23 "$WORK/manifest.txt" "$WORK/reference.txt")"
extra="$(comm -13 "$WORK/manifest.txt" "$WORK/reference.txt" | comm -23 - "$WORK/allow.txt")"
stale_allow="$(comm -12 "$WORK/manifest.txt" "$WORK/allow.txt")"

version="$(jq -r '.version // "unknown"' "$WORK/manifest.json")"
echo "manifest: $source_label (version $version, $(wc -l < "$WORK/manifest.txt" | tr -d ' ') endpoints)"
echo "reference: api/reference.md ($(wc -l < "$WORK/reference.txt" | tr -d ' ') endpoint headings, $(wc -l < "$WORK/allow.txt" | tr -d ' ') allowlisted)"

drift=0
if [[ -n "$missing" ]]; then
  drift=1
  echo ""
  echo "Missing in reference (in the manifest, no '### <endpoint>' entry in api/reference.md):"
  printf '%s\n' "$missing" | sed 's/^/  /'
fi
if [[ -n "$extra" ]]; then
  drift=1
  echo ""
  echo "Extra in reference (documented, not in the manifest, not in api/drift-allowlist.txt):"
  printf '%s\n' "$extra" | sed 's/^/  /'
fi
if [[ -n "$stale_allow" ]]; then
  echo ""
  echo "Note: allowlisted but now in the manifest (remove from api/drift-allowlist.txt):"
  printf '%s\n' "$stale_allow" | sed 's/^/  /'
fi

if [[ $drift -eq 0 ]]; then
  echo "no drift"
else
  echo ""
  echo "drift found: update api/reference.md (and the skills that use these endpoints)"
fi
exit "$drift"

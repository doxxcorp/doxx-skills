#!/usr/bin/env bash
# shellcheck disable=SC2016 # backticks in the issue text are literal Markdown
set -euo pipefail

# Keep one tracking issue in sync with a scheduled `make api-drift` run.
#
#   scripts/api-drift-report.sh RC OUTPUT_FILE
#
# RC is the exit code of scripts/api-drift.sh, OUTPUT_FILE its output.
#   RC 0: no drift. Close the open tracking issue, if there is one.
#   RC 1: drift. Open the tracking issue, or update it. A comment is added
#         only when the drift output changed, so a daily run does not repeat
#         the same notification.
#   RC 2: the manifest could not be fetched or read. Not drift: the issue is
#         left alone and the workflow reports the error on its own.
# Needs `gh` (authenticated through GH_TOKEN) and `jq`. GITHUB_REPOSITORY,
# GITHUB_SERVER_URL and GITHUB_RUN_ID come from GitHub Actions.

TITLE="api-drift: api/reference.md is behind the live Config API manifest"

die() { echo "api-drift-report: $*" >&2; exit 2; }

[[ $# -eq 2 ]] || die "usage: $0 RC OUTPUT_FILE"
rc="$1"
out="$2"
[[ -f "$out" ]] || die "no such file: $out"
repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is not set}"
run_url="${GITHUB_SERVER_URL:-https://github.com}/$repo/actions/runs/${GITHUB_RUN_ID:-unknown}"

# The open tracking issue, found by its exact title.
existing="$(gh issue list --repo "$repo" --state open --limit 200 --json number,title \
  | jq -r --arg t "$TITLE" '[.[] | select(.title == $t)][0].number // empty')"

case "$rc" in
  0)
    if [[ -z "$existing" ]]; then
      echo "no drift; no open tracking issue"
      exit 0
    fi
    gh issue close "$existing" --repo "$repo" --reason completed \
      --comment "No drift any more: api/reference.md matches the live manifest. Run: $run_url"
    echo "no drift; closed #$existing"
    ;;
  1)
    # A fingerprint of the drift lines (not the run link or the date), so an
    # unchanged daily result edits nothing anyone is notified about.
    drift="$(grep -E '^(  |Missing|Note|Extra)' "$out" || true)"
    fp="$(printf '%s' "$drift" | shasum -a 256 2>/dev/null || printf '%s' "$drift" | sha256sum)"
    fp="${fp%% *}"
    body="$(mktemp)"
    trap 'rm -f "$body"' EXIT
    {
      printf '%s\n' '> **In plain words**'
      printf '%s\n' '>'
      printf '%s\n' '> The daily check found API calls that the live doxx.net API describes but our API reference does not, or the other way round. The skills may give wrong or missing instructions for these calls until someone updates the reference and the skills.'
      printf '\n---\n\n'
      printf 'The scheduled `make api-drift` run reports drift between the live manifest (`https://config.doxx.net/`) and `api/reference.md`. Latest run: %s\n\n' "$run_url"
      printf '```\n'
      cat "$out"
      printf '```\n\n'
      printf 'Fix: document each missing endpoint with a `### <name>` heading in `api/reference.md` (and update the skills that use it), or remove headings the manifest no longer lists. Endpoints documented on purpose without a manifest entry go in `api/drift-allowlist.txt` with a reason. The check compares names only: also review params and returns against the manifest.\n\n'
      printf 'This issue is updated by `.github/workflows/api-drift.yml` and closed by it when the drift is gone.\n\n'
      printf '<!-- api-drift-fingerprint: %s -->\n' "$fp"
    } > "$body"

    if [[ -z "$existing" ]]; then
      gh issue create --repo "$repo" --title "$TITLE" --body-file "$body"
      echo "drift; opened the tracking issue"
      exit 0
    fi
    old_fp="$(gh issue view "$existing" --repo "$repo" --json body \
      | jq -r '.body' | sed -n 's/^<!-- api-drift-fingerprint: \([0-9a-f]*\) -->$/\1/p')"
    gh issue edit "$existing" --repo "$repo" --body-file "$body" >/dev/null
    if [[ "$old_fp" != "$fp" ]]; then
      gh issue comment "$existing" --repo "$repo" \
        --body "The drift changed. The issue body has the new output. Run: $run_url"
      echo "drift changed; updated #$existing"
    else
      echo "same drift; refreshed #$existing quietly"
    fi
    ;;
  2)
    echo "manifest unreachable or unreadable: not treated as drift, tracking issue left alone"
    ;;
  *)
    die "unexpected RC: $rc"
    ;;
esac

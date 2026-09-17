#!/usr/bin/env bash
set -euo pipefail

ref="${1:?usage: check-commit-verdict.sh <ref>}"
: "${REPOSITORY:?}"

sha="$(gh api "repos/$REPOSITORY/commits/$ref" --jq .sha)"
runs="$(gh api "repos/$REPOSITORY/actions/workflows/ci.yml/runs?head_sha=$sha&per_page=100" --jq .workflow_runs)"
if [[ "$(jq length <<< "$runs")" == 0 ]]; then
  echo "::error::No CI run covers $ref ($sha), so nothing tested the commit this release builds" >&2
  exit 1
fi

# The newest run wins, so a re-run that repaired an infrastructure failure counts rather than the attempt it replaced.
status="$(jq -r '.[0].status' <<< "$runs")"
conclusion="$(jq -r '.[0].conclusion // "none"' <<< "$runs")"
if [[ "$status" != completed || "$conclusion" != success ]]; then
  echo "::error::CI for $ref ($sha) reports $status/$conclusion, so this commit is not ready to publish" >&2
  exit 1
fi

echo "CI passed on $sha across every runtime" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

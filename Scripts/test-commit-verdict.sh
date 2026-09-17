#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
probe="$(mktemp -d "${TMPDIR:-/tmp}/token-menu-bar-commit-verdict.XXXXXX")"
trap 'rm -rf "$probe"' EXIT
export GITHUB_STEP_SUMMARY="$probe/summary" REPOSITORY=tox-dev/token-menu-bar-macos PATH="$probe/bin:$PATH"

mkdir -p "$probe/bin"
cat > "$probe/bin/gh" << 'STUB'
#!/usr/bin/env bash
case "$2" in
  */commits/*) echo 3d3c42e5aac5ba805825da76410c181273ba90b1 ;;
  *) cat "$RUNS" ;;
esac
STUB
chmod +x "$probe/bin/gh"

expect() {
  local name="$1" expected="$2" actual=0
  : > "$GITHUB_STEP_SUMMARY"
  bash Scripts/check-commit-verdict.sh v9.9.9 > "$probe/out" 2> "$probe/err" || actual=$?
  ((actual == expected)) || {
    echo "$name: expected exit $expected, got $actual" >&2
    cat "$probe/err" >&2
    exit 1
  }
}

echo '[{"status":"completed","conclusion":"success"}]' > "$probe/runs.json"
RUNS="$probe/runs.json" expect "a passing run publishes" 0
grep -Fq 'CI passed on 3d3c42e5aac5ba805825da76410c181273ba90b1' "$GITHUB_STEP_SUMMARY"

echo '[{"status":"completed","conclusion":"failure"}]' > "$probe/runs.json"
RUNS="$probe/runs.json" expect "a failing run stops the release" 1
grep -Fq 'reports completed/failure' "$probe/err"

echo '[{"status":"in_progress","conclusion":null}]' > "$probe/runs.json"
RUNS="$probe/runs.json" expect "an unfinished run stops the release" 1
grep -Fq 'reports in_progress/none' "$probe/err"

echo '[]' > "$probe/runs.json"
RUNS="$probe/runs.json" expect "an untested commit stops the release" 1
grep -Fq 'No CI run covers' "$probe/err"

echo '[{"status":"completed","conclusion":"success"},{"status":"completed","conclusion":"failure"}]' > "$probe/runs.json"
RUNS="$probe/runs.json" expect "the newest run decides" 0

echo "commit verdict gate holds"

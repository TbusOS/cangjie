#!/usr/bin/env bash
# Selftest for claude-code.sh capture hook. Runs the real script against an
# isolated copy under the repo (.capture-selftest), so the live journal is never
# touched and no /tmp is used. Exercises: jq path, python fallback, empty stdin,
# --clean. Exit 0 = all pass.
#
#   bash adapters/capture/selftest.sh

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PYTHONNOUSERSITE=1
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
STAGE="$REPO_DIR/.capture-selftest"
CAP="$STAGE/adapters/capture/claude-code.sh"
JOURNAL="$STAGE/journal/sessions.jsonl"

cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

rm -rf "$STAGE"; mkdir -p "$STAGE/adapters/capture"
cp "$SCRIPT_DIR/claude-code.sh" "$CAP"

pass=0; fail=0
ok()   { pass=$((pass+1)); echo "  ok  - $1"; }
bad()  { fail=$((fail+1)); echo "  FAIL- $1"; }
lines() { [ -f "$JOURNAL" ] && wc -l < "$JOURNAL" | tr -d ' ' || echo 0; }
valid_json() { tail -n1 "$JOURNAL" | jq -e . >/dev/null 2>&1; }
last_field() { tail -n1 "$JOURNAL" | jq -r ".$1 // empty" 2>/dev/null; }

SAMPLE="{\"cwd\":\"$REPO_DIR\",\"transcript_path\":\"/some/where/t.jsonl\",\"hook_event_name\":\"Stop\"}"

# 1) jq path
printf '%s' "$SAMPLE" | bash "$CAP" >/dev/null
[ "$(lines)" = "1" ] && ok "jq path appends 1 line"   || bad "jq path line count = $(lines)"
valid_json && ok "line is valid JSON"                 || bad "line not valid JSON"
[ "$(last_field cwd)" = "$REPO_DIR" ] && ok "cwd captured from payload" || bad "cwd = $(last_field cwd)"
[ "$(last_field transcript)" = "/some/where/t.jsonl" ] && ok "transcript captured" || bad "transcript = $(last_field transcript)"
[ -n "$(last_field head)" ] && ok "git head captured ($(last_field head))" || bad "git head empty"

# 2) python fallback (force, skip jq)
printf '%s' "$SAMPLE" | WHETSTONE_FORCE_PY=1 bash "$CAP" >/dev/null
[ "$(lines)" = "2" ] && ok "python fallback appends 2nd line" || bad "python fallback line count = $(lines)"
[ "$(last_field cwd)" = "$REPO_DIR" ] && ok "python fallback parses cwd" || bad "py cwd = $(last_field cwd)"

# 3) empty stdin -> cwd falls back to invocation PWD (not blank)
printf '' | bash "$CAP" >/dev/null
[ "$(lines)" = "3" ] && ok "empty stdin still records a line" || bad "empty stdin line count = $(lines)"
[ -n "$(last_field cwd)" ] && ok "empty stdin cwd falls back (non-empty)" || bad "empty stdin cwd blank"

# 4) --clean empties the journal
bash "$CAP" --clean >/dev/null
[ "$(lines)" = "0" ] && ok "--clean empties journal" || bad "--clean left $(lines) line(s)"

echo "----"
echo "capture selftest: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

echo "== statusline/randy-seg.sh =="

# Mock stdin JSON the statusline normally receives
STDIN_JSON='{"model":{"display_name":"Opus 4.7"},"session_id":"abc","cwd":"/tmp"}'

# Case A: no state file -> empty output
setup_sandbox
out=$(echo "$STDIN_JSON" | bash "$REPO_ROOT/statusline/randy-seg.sh" 2>/dev/null)
rc=$?
assert "exits 0 when state missing" "[[ $rc -eq 0 ]]"
assert_empty "empty segment when state missing" "$out"
teardown_sandbox

# Case B: enabled=false -> empty output
setup_sandbox
echo '{"enabled":false,"intensity":"dialed"}' > "$HOME/.claude/randy/state-${RANDY_SESSION_KEY}.json"
out=$(echo "$STDIN_JSON" | bash "$REPO_ROOT/statusline/randy-seg.sh" 2>/dev/null)
assert_empty "empty segment when enabled=false" "$out"
teardown_sandbox

# Case C: enabled=true, intensity=dialed -> yellow segment with DIALED text
setup_sandbox
echo '{"enabled":true,"intensity":"dialed"}' > "$HOME/.claude/randy/state-${RANDY_SESSION_KEY}.json"
out=$(echo "$STDIN_JSON" | bash "$REPO_ROOT/statusline/randy-seg.sh" 2>/dev/null)
assert_contains "segment contains MACHO label" "$out" "MACHO"
assert_contains "segment contains DIALED label" "$out" "DIALED"
assert_contains "segment uses yellow ANSI" "$out" $'\033[33m'
teardown_sandbox

# Case D: enabled=true, intensity=full -> red segment with FULL text
setup_sandbox
echo '{"enabled":true,"intensity":"full"}' > "$HOME/.claude/randy/state-${RANDY_SESSION_KEY}.json"
out=$(echo "$STDIN_JSON" | bash "$REPO_ROOT/statusline/randy-seg.sh" 2>/dev/null)
assert_contains "segment contains FULL label" "$out" "FULL"
assert_contains "segment uses red ANSI" "$out" $'\033[31m'
teardown_sandbox

# Case E: corrupted state -> empty output, no crash
setup_sandbox
echo 'garbage' > "$HOME/.claude/randy/state-${RANDY_SESSION_KEY}.json"
out=$(echo "$STDIN_JSON" | bash "$REPO_ROOT/statusline/randy-seg.sh" 2>/dev/null)
rc=$?
assert "exits 0 with corrupted state" "[[ $rc -eq 0 ]]"
assert_empty "empty segment with corrupted state" "$out"
teardown_sandbox

summary

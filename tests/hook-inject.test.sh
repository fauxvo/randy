#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

echo "== hooks/randy-inject.sh =="

# Case A: no state file -> silent, exit 0
setup_sandbox
out=$(bash "$REPO_ROOT/hooks/randy-inject.sh" 2>/dev/null)
rc=$?
assert "exits 0 when state missing" "[[ $rc -eq 0 ]]"
assert_empty "no output when state missing" "$out"
teardown_sandbox

# Case B: state file with enabled=false -> silent, exit 0
setup_sandbox
echo '{"enabled":false,"intensity":"dialed"}' > "$HOME/.claude/randy/state.json"
out=$(bash "$REPO_ROOT/hooks/randy-inject.sh" 2>/dev/null)
rc=$?
assert "exits 0 when enabled=false" "[[ $rc -eq 0 ]]"
assert_empty "no output when enabled=false" "$out"
teardown_sandbox

# Case C: enabled=true, intensity=dialed -> JSON with persona content
setup_sandbox
echo '{"enabled":true,"intensity":"dialed"}' > "$HOME/.claude/randy/state.json"
out=$(bash "$REPO_ROOT/hooks/randy-inject.sh" 2>/dev/null)
rc=$?
assert "exits 0 when enabled=true" "[[ $rc -eq 0 ]]"
assert_contains "output is JSON with hookSpecificOutput" "$out" '"hookSpecificOutput"'
assert_contains "output uses additionalContext field" "$out" '"additionalContext"'
assert_contains "output names UserPromptSubmit event" "$out" '"UserPromptSubmit"'
assert_contains "output mentions dialed intensity" "$out" "intensity: dialed"
assert_contains "output includes persona content" "$out" "Macho Mode: DIALED-IN"
# Verify the JSON parses and additionalContext is populated
parsed=$(echo "$out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)
assert_nonempty "additionalContext parses out as non-empty" "$parsed"
teardown_sandbox

# Case D: enabled=true, intensity=full -> JSON with full persona
setup_sandbox
echo '{"enabled":true,"intensity":"full"}' > "$HOME/.claude/randy/state.json"
out=$(bash "$REPO_ROOT/hooks/randy-inject.sh" 2>/dev/null)
rc=$?
assert "exits 0 when intensity=full" "[[ $rc -eq 0 ]]"
assert_contains "output includes full persona content" "$out" "Macho Mode: FULL MADNESS"
teardown_sandbox

# Case E: corrupted JSON -> silent, exit 0 (no crash, no garbage on stdout)
setup_sandbox
echo 'not valid json {{{' > "$HOME/.claude/randy/state.json"
out=$(bash "$REPO_ROOT/hooks/randy-inject.sh" 2>/dev/null)
rc=$?
assert "exits 0 with corrupted state" "[[ $rc -eq 0 ]]"
assert_empty "no output with corrupted state" "$out"
teardown_sandbox

# Case F: enabled=true but intensity refers to missing persona file
setup_sandbox
echo '{"enabled":true,"intensity":"nonexistent"}' > "$HOME/.claude/randy/state.json"
out=$(bash "$REPO_ROOT/hooks/randy-inject.sh" 2>/dev/null)
rc=$?
assert "exits 0 with missing persona file" "[[ $rc -eq 0 ]]"
assert_empty "no output with missing persona file" "$out"
teardown_sandbox

summary

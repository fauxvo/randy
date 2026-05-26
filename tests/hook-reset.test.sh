#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

echo "== hooks/randy-reset.sh =="

# Case A: state.json exists -> should be deleted, exit 0
setup_sandbox
echo '{"enabled":true,"intensity":"dialed"}' > "$HOME/.claude/randy/state.json"
bash "$REPO_ROOT/hooks/randy-reset.sh"
rc=$?
assert "exits 0 when state existed" "[[ $rc -eq 0 ]]"
assert "state.json removed" "[[ ! -f \"$HOME/.claude/randy/state.json\" ]]"
teardown_sandbox

# Case B: state.json missing -> should be a silent no-op, exit 0
setup_sandbox
bash "$REPO_ROOT/hooks/randy-reset.sh"
rc=$?
assert "exits 0 when state missing" "[[ $rc -eq 0 ]]"
assert "no state.json created" "[[ ! -f \"$HOME/.claude/randy/state.json\" ]]"
teardown_sandbox

# Case C: ~/.claude/randy dir missing entirely -> still exit 0
setup_sandbox
rm -rf "$HOME/.claude/randy"
bash "$REPO_ROOT/hooks/randy-reset.sh"
rc=$?
assert "exits 0 when dir missing" "[[ $rc -eq 0 ]]"
teardown_sandbox

summary

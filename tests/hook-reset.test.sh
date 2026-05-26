#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

echo "== hooks/randy-reset.sh =="

# Case A: per-session state file exists -> should be deleted, exit 0
setup_sandbox
echo '{"enabled":true,"intensity":"dialed"}' > "$HOME/.claude/randy/state-${RANDY_SESSION_KEY}.json"
bash "$REPO_ROOT/hooks/randy-reset.sh"
rc=$?
assert "exits 0 when state existed" "[[ $rc -eq 0 ]]"
assert "state file removed" "[[ ! -f \"$HOME/.claude/randy/state-${RANDY_SESSION_KEY}.json\" ]]"
teardown_sandbox

# Case B: state file missing -> should be a silent no-op, exit 0
setup_sandbox
bash "$REPO_ROOT/hooks/randy-reset.sh"
rc=$?
assert "exits 0 when state missing" "[[ $rc -eq 0 ]]"
assert "no state file created" "[[ ! -f \"$HOME/.claude/randy/state-${RANDY_SESSION_KEY}.json\" ]]"
teardown_sandbox

# Case C: ~/.claude/randy dir missing entirely -> still exit 0
setup_sandbox
rm -rf "$HOME/.claude/randy"
bash "$REPO_ROOT/hooks/randy-reset.sh"
rc=$?
assert "exits 0 when dir missing" "[[ $rc -eq 0 ]]"
teardown_sandbox

# Case D: stale PID state file -> pruned by reset hook
setup_sandbox
# PID 99999999 almost certainly does not exist
echo '{"enabled":true,"intensity":"dialed"}' > "$HOME/.claude/randy/state-99999999.json"
# Also create this session's state file to verify it isn't disturbed
echo '{"enabled":true,"intensity":"dialed"}' > "$HOME/.claude/randy/state-${RANDY_SESSION_KEY}.json"
bash "$REPO_ROOT/hooks/randy-reset.sh"
rc=$?
assert "exits 0 with stale PID file present" "[[ $rc -eq 0 ]]"
assert "stale PID state file pruned" "[[ ! -f \"$HOME/.claude/randy/state-99999999.json\" ]]"
# The reset hook removes THIS session's file (fresh start); that's correct
teardown_sandbox

summary

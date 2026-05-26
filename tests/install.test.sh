#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

echo "== install.sh =="

# Run install.sh inside a sandboxed HOME and verify outcomes.
setup_sandbox

# Pre: empty settings.json
echo '{}' > "$HOME/.claude/settings.json"

# Run installer
bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
rc=$?
assert "install exits 0" "[[ $rc -eq 0 ]]"

# Symlinks exist and point to repo
assert "command symlink exists" "[[ -L \"$HOME/.claude/commands/randy.md\" ]]"
assert "inject hook symlink exists" "[[ -L \"$HOME/.claude/hooks/randy-inject.sh\" ]]"
assert "reset hook symlink exists" "[[ -L \"$HOME/.claude/hooks/randy-reset.sh\" ]]"
assert "statusline symlink exists" "[[ -L \"$HOME/.claude/statusline/randy-seg.sh\" ]]"
assert "persona symlink exists" "[[ -L \"$HOME/.claude/randy/persona\" ]]"
assert "lib symlink exists" "[[ -L \"$HOME/.claude/randy/lib\" ]]"

# settings.json patched correctly
settings_content=$(cat "$HOME/.claude/settings.json")
assert_contains "settings.json mentions randy-inject" "$settings_content" "randy-inject.sh"
assert_contains "settings.json mentions randy-reset" "$settings_content" "randy-reset.sh"
assert_contains "settings.json has UserPromptSubmit" "$settings_content" "UserPromptSubmit"
assert_contains "settings.json has SessionStart" "$settings_content" "SessionStart"

# settings.json is valid JSON
echo "$settings_content" | jq . >/dev/null 2>&1
assert "settings.json is valid JSON" "[[ $? -eq 0 ]]"

# Backup was created
backup_count=$(ls "$HOME/.claude/settings.json.bak."* 2>/dev/null | wc -l)
assert "backup created" "[[ $backup_count -ge 1 ]]"

# Idempotency: run install again, verify no duplicate hook entries
bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
inject_count=$(jq '[.hooks.UserPromptSubmit[].hooks[] | select(.command | test("randy-inject"))] | length' "$HOME/.claude/settings.json")
reset_count=$(jq '[.hooks.SessionStart[].hooks[] | select(.command | test("randy-reset"))] | length' "$HOME/.claude/settings.json")
assert "no duplicate inject entry after re-install" "[[ $inject_count -eq 1 ]]"
assert "no duplicate reset entry after re-install" "[[ $reset_count -eq 1 ]]"

teardown_sandbox

# Case B: install preserves existing unrelated hooks
setup_sandbox
cat > "$HOME/.claude/settings.json" <<'EOF'
{
  "hooks": {
    "UserPromptSubmit": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "bash /tmp/other-hook.sh"}]}
    ]
  }
}
EOF
bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
preserved=$(jq '[.hooks.UserPromptSubmit[].hooks[] | select(.command | test("other-hook"))] | length' "$HOME/.claude/settings.json")
randy_added=$(jq '[.hooks.UserPromptSubmit[].hooks[] | select(.command | test("randy-inject"))] | length' "$HOME/.claude/settings.json")
assert "preexisting unrelated hook preserved" "[[ $preserved -eq 1 ]]"
assert "randy hook added alongside" "[[ $randy_added -eq 1 ]]"
teardown_sandbox

# Case C: install then uninstall -> all symlinks gone, settings.json clean
setup_sandbox
echo '{}' > "$HOME/.claude/settings.json"
bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1
rc=$?
assert "uninstall exits 0" "[[ $rc -eq 0 ]]"
assert "command symlink removed" "[[ ! -L \"$HOME/.claude/commands/randy.md\" ]]"
assert "inject hook symlink removed" "[[ ! -L \"$HOME/.claude/hooks/randy-inject.sh\" ]]"
assert "reset hook symlink removed" "[[ ! -L \"$HOME/.claude/hooks/randy-reset.sh\" ]]"
assert "statusline symlink removed" "[[ ! -L \"$HOME/.claude/statusline/randy-seg.sh\" ]]"
assert "persona symlink removed" "[[ ! -L \"$HOME/.claude/randy/persona\" ]]"
assert "lib symlink removed" "[[ ! -L \"$HOME/.claude/randy/lib\" ]]"
# settings.json no longer mentions randy
settings_content=$(cat "$HOME/.claude/settings.json")
[[ "$settings_content" == *"randy-inject"* ]] && fail=1 || fail=0
assert "settings.json no longer mentions randy-inject" "[[ $fail -eq 0 ]]"
[[ "$settings_content" == *"randy-reset"* ]] && fail=1 || fail=0
assert "settings.json no longer mentions randy-reset" "[[ $fail -eq 0 ]]"
# runtime state files gone (pattern check)
state_count=$(ls "$HOME/.claude/randy/state-"*.json 2>/dev/null | wc -l | tr -d ' ')
assert "runtime state cleaned" "[[ $state_count -eq 0 ]]"
teardown_sandbox

# Case D: uninstall preserves unrelated hooks
setup_sandbox
cat > "$HOME/.claude/settings.json" <<'EOF'
{
  "hooks": {
    "UserPromptSubmit": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "bash /tmp/other-hook.sh"}]}
    ]
  }
}
EOF
bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1
preserved=$(jq '[.hooks.UserPromptSubmit[]?.hooks[]? | select(.command | test("other-hook"))] | length' "$HOME/.claude/settings.json")
randy_gone=$(jq '[.hooks.UserPromptSubmit[]?.hooks[]? | select(.command | test("randy-inject"))] | length' "$HOME/.claude/settings.json")
assert "unrelated hook still present after uninstall" "[[ $preserved -eq 1 ]]"
assert "randy hook removed after uninstall" "[[ $randy_gone -eq 0 ]]"
teardown_sandbox

summary

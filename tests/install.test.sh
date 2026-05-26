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

summary

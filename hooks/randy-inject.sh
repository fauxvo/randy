#!/usr/bin/env bash
# UserPromptSubmit hook for /randy.
# Reads the current session's state file. When enabled, emits Claude Code
# hook JSON {hookSpecificOutput: {hookEventName, additionalContext}} so
# the persona instructions are injected into the model's context.
# Per-session: state file is ~/.claude/randy/state-<claude_pid>.json so
# concurrent Claude Code instances don't share Macho mode.
#
# MUST fail silently — never block the user's prompt.

set -u
trap 'exit 0' ERR

source "$HOME/.claude/randy/lib/randy-common.sh"

STATE_FILE=$(randy_state_file)
PERSONA_DIR="$HOME/.claude/randy/persona"

[[ -f "$STATE_FILE" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

enabled=$(jq -r '.enabled // false' "$STATE_FILE" 2>/dev/null) || exit 0
intensity=$(jq -r '.intensity // "dialed"' "$STATE_FILE" 2>/dev/null) || exit 0

[[ "$enabled" == "true" ]] || exit 0

persona_file="$PERSONA_DIR/${intensity}.md"
[[ -f "$persona_file" ]] || exit 0

reminder=$(printf 'Macho mode is currently ON (intensity: %s). Respond as Randy "Macho Man" Savage per the following persona instructions:\n\n%s' \
  "$intensity" "$(cat "$persona_file")")

jq -n --arg msg "$reminder" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $msg
  }
}'

#!/usr/bin/env bash
# UserPromptSubmit hook for /randy.
# Reads ~/.claude/randy/state.json. When enabled, emits Claude Code
# hook JSON {hookSpecificOutput: {hookEventName, additionalContext}} so
# the persona instructions are injected into the model's context.
# (systemMessage shows text to the user; additionalContext is what
# actually adds context for the model — verified via Context7 docs.)
#
# MUST fail silently — never block the user's prompt.

set -u
trap 'exit 0' ERR

STATE_FILE="$HOME/.claude/randy/state.json"
PERSONA_DIR="$HOME/.claude/randy/persona"

# Silent no-op if state file missing
[[ -f "$STATE_FILE" ]] || exit 0

# Silent no-op if jq missing
command -v jq >/dev/null 2>&1 || exit 0

# Silent no-op if JSON is corrupted (jq will fail; trap catches it)
enabled=$(jq -r '.enabled // false' "$STATE_FILE" 2>/dev/null) || exit 0
intensity=$(jq -r '.intensity // "dialed"' "$STATE_FILE" 2>/dev/null) || exit 0

[[ "$enabled" == "true" ]] || exit 0

persona_file="$PERSONA_DIR/${intensity}.md"
[[ -f "$persona_file" ]] || exit 0

# Build the system reminder body
reminder=$(printf 'Macho mode is currently ON (intensity: %s). Respond as Randy "Macho Man" Savage per the following persona instructions:\n\n%s' \
  "$intensity" "$(cat "$persona_file")")

# Emit Claude Code hook JSON. The hookSpecificOutput.additionalContext
# field is what Claude Code injects into the model's prompt context.
jq -n --arg msg "$reminder" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $msg
  }
}'

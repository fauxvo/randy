#!/usr/bin/env bash
# Statusline segment for /randy.
# Outputs an ANSI-colored "MACHO: DIALED" / "MACHO: FULL" segment when
# Macho mode is on, nothing when off. Reads (and discards) the session
# JSON Claude Code passes on stdin.

set -u
trap 'exit 0' ERR

# Drain stdin so the upstream pipe doesn't break
cat >/dev/null 2>&1 || true

STATE_FILE="$HOME/.claude/randy/state.json"

[[ -f "$STATE_FILE" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

enabled=$(jq -r '.enabled // false' "$STATE_FILE" 2>/dev/null) || exit 0
intensity=$(jq -r '.intensity // "dialed"' "$STATE_FILE" 2>/dev/null) || exit 0

[[ "$enabled" == "true" ]] || exit 0

case "$intensity" in
  full)
    # Red
    printf '\033[31m🕶️ MACHO: FULL\033[0m'
    ;;
  dialed|*)
    # Yellow
    printf '\033[33m🕶️ MACHO: DIALED\033[0m'
    ;;
esac

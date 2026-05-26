#!/usr/bin/env bash
# SessionStart hook for /randy.
# Wipes Macho-mode state so every new Claude Code session starts clean.
# Never fail — never block session startup.

trap 'exit 0' ERR
rm -f "$HOME/.claude/randy/state.json"
exit 0

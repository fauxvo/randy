#!/usr/bin/env bash
# SessionStart hook for /randy.
# Removes THIS session's state file plus any stale state files from
# Claude Code instances that have already exited. Never fails — never
# blocks session startup.

trap 'exit 0' ERR

source "$HOME/.claude/randy/lib/randy-common.sh"

# This session starts with Macho off.
rm -f "$(randy_state_file)" 2>/dev/null || true

# Clean up state files from previous sessions whose processes are gone.
randy_prune_stale_state_files

exit 0

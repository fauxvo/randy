#!/usr/bin/env bash
# Common helpers for /randy components.
# Sourced by hooks, statusline segment, and the /randy slash command.
#
# Centralizes session-key computation so per-session state stays
# isolated across concurrent Claude Code instances.

# randy_session_key
#
# Returns a stable identifier for the current Claude Code session.
# Resolution order:
#   1. RANDY_SESSION_KEY env var (set by tests; lets sandboxes own a key).
#   2. Walk up the process tree from $$ looking for a process whose
#      command is `claude` or ends in `/claude`. That PID is the key.
#   3. Fallback: "shared" — preserves pre-fix behavior rather than
#      crashing if process discovery fails.
randy_session_key() {
  if [[ -n "${RANDY_SESSION_KEY:-}" ]]; then
    printf '%s' "$RANDY_SESSION_KEY"
    return 0
  fi
  local pid=$$
  local depth=0
  while [[ -n "$pid" && "$pid" -gt 1 && "$depth" -lt 20 ]]; do
    local cmd
    cmd=$(ps -p "$pid" -o comm= 2>/dev/null | tr -d '[:space:]')
    if [[ "$cmd" == "claude" || "$cmd" == */claude ]]; then
      printf '%s' "$pid"
      return 0
    fi
    pid=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d '[:space:]')
    depth=$((depth + 1))
  done
  printf '%s' "shared"
}

# randy_state_file
# Returns the absolute path to the current session's state file.
randy_state_file() {
  printf '%s/.claude/randy/state-%s.json' "$HOME" "$(randy_session_key)"
}

# randy_prune_stale_state_files
# Removes ~/.claude/randy/state-<pid>.json files where <pid> no longer
# refers to a running process. Called by the SessionStart hook so
# orphaned state files from previous Claude Code instances don't pile up.
# Also removes the legacy ~/.claude/randy/state.json from pre-fix installs.
randy_prune_stale_state_files() {
  local dir="$HOME/.claude/randy"
  [[ -d "$dir" ]] || return 0
  local f base pid
  for f in "$dir"/state-*.json; do
    [[ -e "$f" ]] || continue
    base=$(basename "$f")
    pid="${base#state-}"
    pid="${pid%.json}"
    if [[ "$pid" =~ ^[0-9]+$ ]]; then
      if ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$f"
      fi
    fi
  done
  # One-time cleanup of legacy shared-state file from pre-per-session installs.
  rm -f "$dir/state.json"
}

#!/usr/bin/env bash
# Uninstall the /randy skill from ~/.claude/.
# Idempotent: re-running is safe.

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

green() { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }

# Step 1: remove symlinks (only if they are symlinks — never delete real files)
rm_symlink() {
  local path="$1"
  if [[ -L "$path" ]]; then
    rm "$path"
  fi
}

rm_symlink "$CLAUDE_DIR/commands/randy.md"
rm_symlink "$CLAUDE_DIR/hooks/randy-inject.sh"
rm_symlink "$CLAUDE_DIR/hooks/randy-reset.sh"
rm_symlink "$CLAUDE_DIR/statusline/randy-seg.sh"
rm_symlink "$CLAUDE_DIR/randy/persona"

# Step 2: prune settings.json (requires jq)
if command -v jq >/dev/null 2>&1; then
  SETTINGS="$CLAUDE_DIR/settings.json"
  if [[ -f "$SETTINGS" ]]; then
    BACKUP="$CLAUDE_DIR/settings.json.bak.$TIMESTAMP"
    cp "$SETTINGS" "$BACKUP"
    tmp=$(mktemp)
    jq '
      # Strip any UserPromptSubmit / SessionStart entries whose command mentions randy-*.
      # Then drop now-empty arrays / containers for cleanliness.

      def prune_event(name):
        if (.hooks // {}) | has(name) then
          .hooks[name] = (
            .hooks[name]
            | map(
                .hooks |= map(select(.command | test("randy-(inject|reset)\\.sh") | not))
                | select(.hooks | length > 0)
              )
          )
          | (if .hooks[name] == [] then del(.hooks[name]) else . end)
        else . end;

      prune_event("UserPromptSubmit")
      | prune_event("SessionStart")
      | (if (.hooks // {}) == {} then del(.hooks) else . end)
    ' "$SETTINGS" > "$tmp"
    mv "$tmp" "$SETTINGS"
    green "Pruned $SETTINGS (backup: $BACKUP)"
  fi
else
  yellow "jq missing — settings.json was not pruned. Remove randy hook entries manually."
fi

# Step 3: remove runtime state and (empty) ~/.claude/randy dir
rm -f "$CLAUDE_DIR/randy/state.json"
if [[ -d "$CLAUDE_DIR/randy" ]]; then
  rmdir "$CLAUDE_DIR/randy" 2>/dev/null || true
fi

green "Uninstall complete."
cat <<'EOF'

If you added the randy segment to a custom statusline composer, remove
the call to ~/.claude/statusline/randy-seg.sh from your statusline
script manually.
EOF

#!/usr/bin/env bash
# Install the /randy skill into ~/.claude/.
# Idempotent: re-running is safe.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

red() { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }

# Step 1: jq check (required for hooks)
if ! command -v jq >/dev/null 2>&1; then
  yellow "WARNING: jq is not installed. /randy hooks require jq to run."
  yellow "  Install with: brew install jq  (or apt install jq)"
fi

# Step 2: ensure target directories exist
mkdir -p "$CLAUDE_DIR/commands" "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/statusline" "$CLAUDE_DIR/randy"

# Step 3: chmod +x source scripts (warn loudly if chmod fails — silent
# failure here means hooks won't execute and Macho mode appears to do nothing)
if ! chmod +x "$REPO_ROOT/hooks/randy-inject.sh" \
              "$REPO_ROOT/hooks/randy-reset.sh" \
              "$REPO_ROOT/statusline/randy-seg.sh" \
              "$REPO_ROOT/install.sh" \
              "$REPO_ROOT/uninstall.sh" 2>/dev/null; then
  yellow "WARNING: chmod +x failed on one or more scripts. Hooks may not execute."
fi

# Step 4: create symlinks
# - If a symlink already exists at the destination, replace it (idempotent re-install).
# - If a real directory exists (e.g., the persona dir from a prior install before
#   we switched to symlinking, or test setup), replace it with the symlink.
# - If a real file exists, refuse — never clobber user files.
ln_safe() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then
    rm "$dst"
  elif [[ -d "$dst" ]]; then
    rm -rf "$dst"
  elif [[ -e "$dst" ]]; then
    red "ERROR: $dst exists and is not a symlink. Refusing to overwrite."
    exit 1
  fi
  ln -s "$src" "$dst"
}

ln_safe "$REPO_ROOT/commands/randy.md"        "$CLAUDE_DIR/commands/randy.md"
ln_safe "$REPO_ROOT/hooks/randy-inject.sh"    "$CLAUDE_DIR/hooks/randy-inject.sh"
ln_safe "$REPO_ROOT/hooks/randy-reset.sh"     "$CLAUDE_DIR/hooks/randy-reset.sh"
ln_safe "$REPO_ROOT/statusline/randy-seg.sh"  "$CLAUDE_DIR/statusline/randy-seg.sh"
ln_safe "$REPO_ROOT/persona"                  "$CLAUDE_DIR/randy/persona"

# Step 5: settings.json patch (requires jq)
if command -v jq >/dev/null 2>&1; then
  SETTINGS="$CLAUDE_DIR/settings.json"
  BACKUP="$CLAUDE_DIR/settings.json.bak.$TIMESTAMP"

  if [[ -f "$SETTINGS" ]]; then
    cp "$SETTINGS" "$BACKUP"
  else
    echo '{}' > "$SETTINGS"
    cp "$SETTINGS" "$BACKUP"
  fi

  inject_cmd="bash $CLAUDE_DIR/hooks/randy-inject.sh"
  reset_cmd="bash $CLAUDE_DIR/hooks/randy-reset.sh"

  # Patch with jq: add hook entries only if not already present.
  # We compose a new object and write to a temp file, then mv.
  tmp=$(mktemp)
  jq \
    --arg inject_cmd "$inject_cmd" \
    --arg reset_cmd  "$reset_cmd" \
    '
    # Ensure the .hooks object exists
    .hooks = (.hooks // {}) |

    # UserPromptSubmit: append randy entry only if not present
    .hooks.UserPromptSubmit = (.hooks.UserPromptSubmit // []) |
    (if any(.hooks.UserPromptSubmit[]?; .hooks[]?.command == $inject_cmd)
     then .
     else .hooks.UserPromptSubmit += [{
       "matcher": "*",
       "hooks": [{"type": "command", "command": $inject_cmd}]
     }] end) |

    # SessionStart: append randy entry only if not present
    .hooks.SessionStart = (.hooks.SessionStart // []) |
    (if any(.hooks.SessionStart[]?; .hooks[]?.command == $reset_cmd)
     then .
     else .hooks.SessionStart += [{
       "matcher": "*",
       "hooks": [{"type": "command", "command": $reset_cmd}]
     }] end)
    ' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  green "Patched $SETTINGS (backup: $BACKUP)"
else
  red "Skipped settings.json patch — jq missing. Run install again after installing jq."
fi

# Step 6: print statusline integration snippet
cat <<'SNIPPET'

──────────────────────────────────────────────────────────────────
  /randy statusline integration
──────────────────────────────────────────────────────────────────
To show the Macho indicator in your statusline, add a call to the
randy segment script in your existing statusline command. Example:

  ~/.claude/statusline/randy-seg.sh

The segment outputs an ANSI-colored "🕶️ MACHO: DIALED" (yellow) or
"🕶️ MACHO: FULL" (red) string when Macho mode is on, and nothing
when off. Pipe its output through your statusline composition layer
like any other segment.

If you don't already have a custom statusline, the minimal snippet
is in your ~/.claude/settings.json:

  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline/randy-seg.sh"
  }
──────────────────────────────────────────────────────────────────

SNIPPET

# Step 7: success + verification
green "Install complete."
cat <<'EOF'

Verify with:
  /randy status     -> should report "Macho mode is OFF"
  /randy on         -> enables dialed Macho voice
  Ask a question    -> assistant responds as Macho Man
  /randy off        -> disables Macho voice
EOF

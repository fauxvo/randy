---
name: randy
description: 'Toggle Randy "Macho Man" Savage voice for Claude responses. Args: on [dialed|full] | off | status'
---

The user has invoked `/randy $ARGUMENTS`.

You are managing the Macho Man voice toggle for this Claude Code session. The state lives in a per-session file resolved via `~/.claude/randy/lib/randy-common.sh`. Interpret the arguments and act:

## Argument handling

Parse `$ARGUMENTS` (which may be empty or contain one or two whitespace-separated words):

- **No arguments** OR **`status`** → Source `~/.claude/randy/lib/randy-common.sh`, call `randy_state_file` to get the per-session state path, read that file (if it exists), and report current state to the user in plain (non-Macho) prose. Show `enabled`, `intensity`, and `started_at`. If the file is missing, report "Macho mode is OFF."
- **`on`** OR **`on dialed`** → Enable Macho mode at dialed intensity. Use the Bash tool to write the state file (see template below). Confirm to the user with a single Macho-flavored line.
- **`on full`** → Enable Macho mode at full intensity. Use the Bash tool to write the state file with `intensity: "full"`. Confirm with a single (extra-loud) Macho line.
- **`off`** → Disable Macho mode. Use the Bash tool to source the helper and remove the per-session file: `source ~/.claude/randy/lib/randy-common.sh && rm -f "$(randy_state_file)"`. Confirm with a single neutral line.
- **Anything else** → Print a one-paragraph help message listing the supported forms.

## State file template (use exactly this shape)

When writing the state file, use the Bash tool with a heredoc to produce JSON like:

```json
{
  "enabled": true,
  "intensity": "dialed",
  "started_at": "<current UTC ISO-8601 timestamp>"
}
```

Source `~/.claude/randy/lib/randy-common.sh` and call `randy_state_file` to get the correct per-session path. Use `mkdir -p` on the file's directory first. Use `date -u +"%Y-%m-%dT%H:%M:%SZ"` for the timestamp.

Example bash invocation for `on dialed`:

```bash
source ~/.claude/randy/lib/randy-common.sh
state_file=$(randy_state_file)
mkdir -p "$(dirname "$state_file")"
cat > "$state_file" <<EOF
{
  "enabled": true,
  "intensity": "dialed",
  "started_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
```

## Important constraints

- Do NOT use Macho voice for the `status` or `off` confirmations — keep those plain.
- Do NOT use Macho voice for any errors (e.g., write failures).
- The Macho voice in the `on` confirmation should be brief (one sentence). The next user message will get full Macho treatment via the UserPromptSubmit hook.
- If `$ARGUMENTS` is the literal text `$ARGUMENTS` (i.e. Claude Code did not substitute, suggesting a misconfiguration), treat it as empty.

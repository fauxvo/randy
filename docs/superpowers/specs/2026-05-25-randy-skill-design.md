# `/randy` — Macho Man Randy Savage Voice Toggle for Claude Code

**Status:** Design approved (revised 2026-05-25 after Claude Code mechanism verification)
**Date:** 2026-05-25
**Author:** Matt Read (with Claude)

## Revision History

- **2026-05-25 (initial):** Original design assuming UserPromptSubmit hook receives `$CLAUDE_SESSION_ID` and that hook stdout is directly injected into context.
- **2026-05-25 (revised):** Verified via claude-code-guide that (a) UserPromptSubmit does NOT receive `$CLAUDE_SESSION_ID`, (b) hooks must emit JSON `{systemMessage: "..."}` to inject context, (c) slash commands are prompt templates the assistant interprets, not executed shell. Replaced session_id check with a SessionStart hook that wipes state on every new session — simpler and more reliable.

## Summary

A Claude Code slash command (`/randy`) that toggles assistant chat responses into the voice of Randy "Macho Man" Savage. Toggle mode persists across conversation turns within a Claude Code session via a marker file and a `UserPromptSubmit` hook. A statusline segment provides at-a-glance state.

The personality wrapper applies only to assistant prose in chat. Files written to disk, code, plans, tool arguments, and safety warnings remain professional.

## Goals

- Fun, recognizable Macho Man voice on demand
- Reliable persistence across turns (no drift back to normal Claude)
- Zero impact on artifacts: code, files, plans, commits stay clean
- Session-scoped — a fresh Claude Code session starts with Macho off
- Tunable intensity: a readable "dialed-in" default plus a maximal "full Madness" mode
- Source-controlled in `~/projects/randy/`, installed globally via symlinks for use in any project

## Non-Goals (YAGNI)

- Multiple personas / generalized voice-toggle framework — only Macho Man
- Conversation-level toggle (session-level is sufficient)
- Automated voice-quality testing — manual smoke tests only
- Web UI or configuration GUI
- Transforming user input (only assistant output)
- ANSI color codes in chat output (renderer support is undocumented — markdown emphasis only in chat)

## User Stories

1. **As a developer,** I want to type `/randy on` and have all subsequent assistant responses come back in Macho Man's voice, so my work sessions are more fun.
2. **As a developer,** I want `/randy off` to restore normal Claude voice immediately.
3. **As a developer,** I want `/randy on full` to crank the intensity for max comedic effect.
4. **As a developer,** I want files, code, plans, and safety warnings to stay clean and professional even when Macho mode is on, so my work artifacts aren't compromised.
5. **As a developer,** I want a quick "be serious" escape phrase that gives me a clean response for one turn without fully toggling off.
6. **As a developer,** I want a statusline indicator so I can see at a glance whether Macho mode is on.
7. **As a developer,** I want a fresh Claude Code session to start with Macho off, so I don't get surprised when I come back tomorrow.

## Architecture

### File layout (source of truth, in `~/projects/randy/`)

```
~/projects/randy/
├── commands/
│   └── randy.md              # slash command (prompt template)
├── hooks/
│   ├── randy-inject.sh       # UserPromptSubmit hook (injects persona)
│   └── randy-reset.sh        # SessionStart hook (wipes state.json)
├── statusline/
│   └── randy-seg.sh          # statusline segment script
├── persona/
│   ├── dialed.md             # voice instructions for dialed-in intensity
│   └── full.md               # voice instructions for full Madness
├── tests/
│   ├── hook-inject.test.sh   # smoke tests for inject hook
│   ├── hook-reset.test.sh    # smoke test for reset hook
│   ├── statusline.test.sh    # smoke tests for statusline segment
│   └── install.test.sh       # sandboxed install/uninstall round-trip
├── install.sh                # installs symlinks + settings.json entries
├── uninstall.sh              # reverses install
├── README.md                 # docs + manual test checklist
└── docs/
    └── superpowers/
        └── specs/
            └── 2026-05-25-randy-skill-design.md
```

### After install (in `~/.claude/`)

```
~/.claude/commands/randy.md           → symlink to ~/projects/randy/commands/randy.md
~/.claude/hooks/randy-inject.sh       → symlink to ~/projects/randy/hooks/randy-inject.sh
~/.claude/hooks/randy-reset.sh        → symlink to ~/projects/randy/hooks/randy-reset.sh
~/.claude/statusline/randy-seg.sh     → symlink to ~/projects/randy/statusline/randy-seg.sh
~/.claude/randy/persona/              → symlink to ~/projects/randy/persona/
~/.claude/randy/state.json            # runtime state (NOT symlinked, NOT in git)
~/.claude/settings.json                # extended with TWO hook registrations
```

### Data flow

On Claude Code session start:

```
Claude Code launches
  → SessionStart hook fires
  → randy-reset.sh deletes ~/.claude/randy/state.json (if present)
  → Macho mode is now off in this session
```

On every user message:

```
User types message
  → Claude Code fires UserPromptSubmit hook
  → randy-inject.sh runs:
      reads ~/.claude/randy/state.json
      if missing or enabled=false → emit nothing (exit 0), Claude responds normally
      else → read persona/{dialed|full}.md, emit JSON {"systemMessage": "<persona>"} on stdout
  → Claude Code injects the systemMessage into Claude's context as a system reminder
  → Claude responds in Macho voice
```

On `/randy on|off|status`:

```
User types /randy <args>
  → Claude Code expands the slash-command markdown template with $ARGUMENTS substituted
  → The expanded text becomes Claude's next prompt
  → Claude (per the command body's instructions) uses the Bash tool to:
      - write or delete ~/.claude/randy/state.json
      - emit a short confirmation message to the user
```

## Behavior Contract

### Slash command surface

| Command | Effect |
|---|---|
| `/randy on` | Enable Macho mode at **dialed** intensity (default) |
| `/randy on dialed` | Same as above, explicit |
| `/randy on full` | Enable at **full Madness** intensity |
| `/randy off` | Disable Macho mode (delete state file) |
| `/randy status` | Show current state (on/off, intensity, started_at) |
| `/randy` (no arg) | Show short help + current status |

### Marker file format (`~/.claude/randy/state.json`)

```json
{
  "enabled": true,
  "intensity": "dialed",
  "started_at": "2026-05-25T16:30:00Z"
}
```

The file's mere presence (with `enabled: true`) is enough to activate Macho mode. The `SessionStart` hook (`randy-reset.sh`) deletes this file whenever a new Claude Code session begins, providing the session-keyed behavior. There is no `session_id` field — `$CLAUDE_SESSION_ID` is not available to `UserPromptSubmit` hooks, and the SessionStart wipe makes per-message session matching unnecessary.

### Hook behavior

Two hooks total, both registered in `~/.claude/settings.json`.

#### `randy-reset.sh` — SessionStart hook

```bash
#!/usr/bin/env bash
# Wipe randy state on every new Claude Code session.
# Fail silently — never block session startup.
trap 'exit 0' ERR
rm -f "$HOME/.claude/randy/state.json"
exit 0
```

#### `randy-inject.sh` — UserPromptSubmit hook

```bash
#!/usr/bin/env bash
set -e
STATE_FILE="$HOME/.claude/randy/state.json"
PERSONA_DIR="$HOME/.claude/randy/persona"

# Fail silently — never block the user's prompt
trap 'exit 0' ERR

[[ -f "$STATE_FILE" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

enabled=$(jq -r '.enabled // false' "$STATE_FILE")
intensity=$(jq -r '.intensity // "dialed"' "$STATE_FILE")

[[ "$enabled" == "true" ]] || exit 0

persona_file="$PERSONA_DIR/${intensity}.md"
[[ -f "$persona_file" ]] || exit 0

# Build the system reminder message
reminder="Macho mode is currently ON (intensity: $intensity). Respond as Randy \"Macho Man\" Savage per the following persona instructions:

$(cat "$persona_file")"

# Emit Claude Code hook JSON to inject the reminder
jq -n --arg msg "$reminder" '{systemMessage: $msg}'
```

The hook's stdout MUST be valid JSON with a `systemMessage` field — that is what Claude Code's hook protocol requires to inject context. Plain stdout text is logged but not injected.

### Persona file contents

Each persona file (`dialed.md`, `full.md`) contains:

1. **Voice guidelines** — cadence, vocabulary, signature phrases
2. **Hard rules** that are NEVER violated:
   - Code blocks stay clean (no Macho-ified variable names or wrestling-themed comments)
   - File contents written to disk stay clean
   - Tool call arguments / shell commands stay clean
   - Plan documents and design specs stay clean
   - Critical safety / destructive-action warnings stay clean
   - Error messages from tools (the raw output) stay clean — but commentary on them goes Macho
   - Escape phrases — if the user's message contains any of: "be serious", "drop the act", "no macho", "serious mode" — drop character for that response only, marker stays
3. **Markdown emphasis guidelines** — `**OHHH YEAH!**` for standard catchphrase emphasis, `***DIG IT?***` for max emphasis, `> "Madness! MADNESS, I say!"` blockquotes for full promo monologues, ALL CAPS + multiple exclamation marks for shouted parts, occasional 🤼/💪/🕶️ emoji
4. **Catchphrase library** — Ohh yeah!, Dig it?, Cream of the crop, Tower of power (too sweet to be sour), Madness/Macho Madness, references to himself in third person ("The Macho Man"), cosmic/grandiose framing
5. **Examples** — good vs. bad Macho responses

The two files differ in **density**, not rules:
- `dialed.md`: 1–2 catchphrases per response, voice modulation present but the response is still readable for actual work
- `full.md`: lean into it — rhyme constantly, ALL CAPS frequent, every response a wrestling promo

### Edge cases

| Case | Behavior |
|---|---|
| New Claude Code session | SessionStart hook (`randy-reset.sh`) deletes state.json → fresh start |
| Escape phrase in prompt | Persona instructions tell Claude to detect and drop character for that response, marker stays |
| `/randy on` when already on | Overwrites state.json with new intensity, no error |
| `/randy off` when already off | No-op (state file already absent), no error |
| Hook script error | `trap 'exit 0' ERR` ensures it fails silently — never blocks the prompt |
| State file corrupted JSON | `jq` returns empty / hook treats as off, exits 0 cleanly |
| Missing `jq` binary | Hook exits 0 (Macho mode silently inactive). `install.sh` checks for `jq` and warns if absent. |
| Multiple Claude Code instances open concurrently | They share `~/.claude/randy/state.json` — toggling in one affects all. Documented as a known limitation. |

## Statusline Integration

A small script (`statusline/randy-seg.sh`) outputs the Macho segment or nothing. Claude Code passes a JSON blob on stdin (containing `model`, `cwd`, `session_id`, `context_window`, etc.) — the script reads it but the segment only depends on `~/.claude/randy/state.json`.

| State | Output (ANSI-colored) |
|---|---|
| Off | (empty string — segment disappears) |
| Dialed | `🕶️ MACHO: DIALED` in **yellow** (`\033[33m`) |
| Full | `🕶️ MACHO: FULL` in **red** (`\033[31m`) |

### Install strategy for statusline

The user already has a custom statusline (`randy | Opus 4.7 (1M context) | Ctx: 6% | ...`). We must not clobber it.

**Strategy 2 (chosen):** `install.sh` prints a snippet for the user to manually paste into their statusline script. No automatic modification of the user's statusline.

Future opt-in: `install.sh --auto-patch-statusline` could detect and inject the segment, with backup. Not in v1.

## Chat Color Treatment

Confirmed via claude-code-guide: Claude Code's chat renderer does NOT document support for ANSI escape codes or HTML `<span>` color tags in assistant output. Markdown emphasis (bold, italic, blockquote, code) is the only reliable visual treatment.

Decision: **No color in chat output.** Catchphrase emphasis uses:
- `**OHHH YEAH!**` (bold)
- `***DIG IT?***` (bold-italic)
- `> "Madness! MADNESS, I say!"` (blockquote)
- ALL CAPS for shouted parts
- 🤼 / 💪 / 🕶️ emoji as occasional accents

Color is reserved for the statusline, where it's confirmed to work.

## Install Flow

`install.sh` is idempotent. Run from `~/projects/randy/`:

1. Check `jq` is installed; warn if not (required for hooks and statusline)
2. Create `~/.claude/randy/` directory
3. `chmod +x` source scripts (`hooks/randy-inject.sh`, `hooks/randy-reset.sh`, `statusline/randy-seg.sh`, `install.sh`, `uninstall.sh`)
4. Create symlinks:
   - `~/.claude/commands/randy.md` → source
   - `~/.claude/hooks/randy-inject.sh` → source
   - `~/.claude/hooks/randy-reset.sh` → source
   - `~/.claude/statusline/randy-seg.sh` → source
   - `~/.claude/randy/persona/` → source persona dir
5. Backup `~/.claude/settings.json` to `~/.claude/settings.json.bak.<timestamp>`
6. Patch `~/.claude/settings.json` to register both hooks:
   - `UserPromptSubmit` matcher `*` → `bash ~/.claude/hooks/randy-inject.sh`
   - `SessionStart` matcher `*` → `bash ~/.claude/hooks/randy-reset.sh`
   - Both entries idempotent — if a randy-* registration is already present, skip; if non-randy registrations exist for these events, append rather than replace
7. Print the statusline snippet for the user to paste into their statusline script
8. Print success message + verification commands:
   - `/randy status` (should show off)
   - `/randy on` then re-prompt (should respond in Macho voice)
   - `/randy off` (should restore normal)

`uninstall.sh` reverses everything:
1. Remove all symlinks created by install
2. Patch `~/.claude/settings.json` to remove only the randy-* hook entries (preserving other registrations); backup first
3. Delete `~/.claude/randy/` runtime directory
4. Print the statusline snippet the user needs to manually remove

## Testing Approach

Manual smoke test checklist (in `README.md`):

1. **Toggle round-trip:** `/randy on` → ask a question → verify Macho voice → `/randy off` → ask again → verify clean
2. **Intensity:** `/randy on full` vs. `/randy on dialed` — verify difference (ALL CAPS / rhymes / promo energy in full)
3. **Safety boundary:** With Macho on, request a destructive action — verify warning is clean
4. **Code purity:** With Macho on, request a code change — verify file contents are clean, only chat prose is Macho
5. **Escape phrase:** With Macho on, say "be serious for a sec" → verify clean response → next message → back to Macho
6. **Session reset:** `/randy on`, quit Claude Code, restart, new conversation → verify Macho is off (stale session_id)
7. **Statusline:** Toggle on/off/full → verify segment appears/disappears with correct colors
8. **Hook resilience:** Corrupt the state.json, send a prompt — verify hook fails silently, prompt still works
9. **Install/uninstall round-trip:** Install, verify works, uninstall, verify clean

## Resolved Open Questions

All implementation-time unknowns from the initial draft have been verified via claude-code-guide (cited against `code.claude.com/docs` v2.1.x, 2026-05-25):

- **Hook event name:** `UserPromptSubmit` (PascalCase, exact).
- **Hook registration schema:** Nested under `hooks.UserPromptSubmit[].hooks[]` with `type: "command"` and `command: "bash ..."` (see Hook Behavior section for the actual JSON shape).
- **Hook output:** Hooks must emit JSON with a `systemMessage` field on stdout to inject context. Plain text is logged but not injected.
- **Hook env vars:** `UserPromptSubmit` receives `CLAUDE_PROJECT_DIR`, `CLAUDE_PLUGIN_ROOT`, `CLAUDE_PLUGIN_DATA`, `CLAUDE_EFFORT`. **Not** `CLAUDE_SESSION_ID` — hence the SessionStart-hook approach for session-keyed behavior.
- **Slash command model:** Prompt template, not executed shell. `$ARGUMENTS` / `$1` / `$N` are substituted into the markdown body before Claude reads it. Env vars are unavailable inside the template body.
- **Statusline:** Receives full session JSON on stdin (includes `session_id`, `model`, `cwd`, etc.), outputs plain text + ANSI. Refreshes event-driven with 300ms debounce; optional `refreshInterval` for time-based data.

## Acceptance Criteria

The skill is "done" when all nine manual smoke tests pass and the README documents:
- What the skill does
- How to install / uninstall
- All slash command variants
- The escape phrase mechanism
- The manual test checklist

# `/randy` Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code slash command `/randy` that toggles assistant chat responses into Randy "Macho Man" Savage's voice, persisting per-session via a marker file and two hooks, with a statusline indicator.

**Architecture:** A SessionStart hook clears `~/.claude/randy/state.json` on every new Claude Code session. A UserPromptSubmit hook reads `state.json` and (when enabled) emits JSON `{"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "<persona>"}}`, which Claude Code injects into the model's prompt context. The slash command is a prompt template that instructs the assistant to use the Bash tool to write/delete the state file. A statusline shell script renders the current state with ANSI color.

**Tech Stack:** Bash, `jq`, Claude Code (hooks, slash commands, statusline). No JavaScript/TypeScript runtime. No package manager. Tests are plain bash scripts in `tests/`.

**Spec:** `docs/superpowers/specs/2026-05-25-randy-skill-design.md`

---

## Conventions used throughout this plan

- All paths shown relative to repo root (`/Users/mattread/projects/randy/`) unless absolute.
- All shell commands assume the working directory is the repo root.
- Tests are runnable directly: `bash tests/<name>.test.sh`. They exit 0 on pass, non-zero on fail.
- Each test creates an isolated sandbox HOME under `$TMPDIR` and tears it down.
- Commit messages follow Conventional Commits style (`feat:`, `test:`, `docs:`, etc.) with a `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` trailer.

---

## Task 1: Project Scaffolding

**Files:**
- Create: `commands/.gitkeep`, `hooks/.gitkeep`, `statusline/.gitkeep`, `persona/.gitkeep`, `tests/.gitkeep`
- Create: `README.md` (placeholder)

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p commands hooks statusline persona tests
touch commands/.gitkeep hooks/.gitkeep statusline/.gitkeep persona/.gitkeep tests/.gitkeep
```

- [ ] **Step 2: Create placeholder README**

Write `README.md` with:

```markdown
# /randy

Macho Man Randy Savage voice toggle for Claude Code chat.

**Status:** In development. See `docs/superpowers/plans/2026-05-25-randy-skill-implementation.md`.

OHHH YEAH! Brother!
```

- [ ] **Step 3: Verify layout**

Run: `ls -la commands hooks statusline persona tests`
Expected: Each directory exists and contains a `.gitkeep`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore: scaffold directory structure

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Test Harness Common Helpers

A small bash library used by every `*.test.sh` to set up an isolated sandbox HOME and report pass/fail.

**Files:**
- Create: `tests/common.sh`

- [ ] **Step 1: Write `tests/common.sh`**

```bash
#!/usr/bin/env bash
# Common helpers for randy shell tests.
# Source this file from each test script.

set -u

# Counters (consumed by `summary` at end of each test file)
PASS=0
FAIL=0
FAILURES=()

# Repo root, derived from this file's location
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# setup_sandbox: create a temp HOME and export it.
# Sets SANDBOX, exports HOME=SANDBOX, creates ~/.claude/ skeleton.
setup_sandbox() {
  SANDBOX=$(mktemp -d -t randy-test.XXXXXX)
  export HOME="$SANDBOX"
  mkdir -p "$HOME/.claude/randy"
  # Mirror persona files into sandbox so hooks can find them
  cp -R "$REPO_ROOT/persona" "$HOME/.claude/randy/persona"
}

# teardown_sandbox: clean up the temp HOME
teardown_sandbox() {
  if [[ -n "${SANDBOX:-}" && -d "$SANDBOX" ]]; then
    rm -rf "$SANDBOX"
  fi
  unset SANDBOX
}

# assert: report pass/fail for a boolean condition
# usage: assert "description" "[[ ... ]]"
assert() {
  local desc="$1"
  local cond="$2"
  if eval "$cond"; then
    PASS=$((PASS + 1))
    printf "  \033[32mPASS\033[0m  %s\n" "$desc"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$desc")
    printf "  \033[31mFAIL\033[0m  %s\n" "$desc"
  fi
}

# assert_contains: check that a value contains a substring
assert_contains() {
  local desc="$1"
  local haystack="$2"
  local needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
    printf "  \033[32mPASS\033[0m  %s\n" "$desc"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$desc — expected to contain: $needle")
    printf "  \033[31mFAIL\033[0m  %s\n" "$desc"
    printf "         expected substring: %q\n" "$needle"
    printf "         actual: %q\n" "$haystack"
  fi
}

# assert_empty: check that a value is the empty string
assert_empty() {
  local desc="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    PASS=$((PASS + 1))
    printf "  \033[32mPASS\033[0m  %s\n" "$desc"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$desc — expected empty")
    printf "  \033[31mFAIL\033[0m  %s\n" "$desc"
    printf "         actual: %q\n" "$value"
  fi
}

# summary: print results and exit with appropriate code
summary() {
  local total=$((PASS + FAIL))
  printf "\n  %d passed, %d failed (of %d)\n" "$PASS" "$FAIL" "$total"
  if [[ $FAIL -gt 0 ]]; then
    printf "\n  Failures:\n"
    for f in "${FAILURES[@]}"; do
      printf "    - %s\n" "$f"
    done
    exit 1
  fi
}
```

- [ ] **Step 2: Smoke-test the harness itself**

Write `tests/_harness.test.sh`:

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

echo "== harness self-test =="
setup_sandbox
assert "sandbox HOME is a real dir" "[[ -d \"$HOME/.claude/randy\" ]]"
assert_contains "assert_contains works" "hello world" "world"
assert_empty "assert_empty works" ""
teardown_sandbox
summary
```

- [ ] **Step 3: Run harness self-test**

Run: `bash tests/_harness.test.sh`
Expected:
```
== harness self-test ==
  PASS  sandbox HOME is a real dir
  PASS  assert_contains works
  PASS  assert_empty works

  3 passed, 0 failed (of 3)
```

(Note: persona dir doesn't exist yet — the `cp` in setup_sandbox will warn. That's fine for now; we'll fix in Task 3 when we create the persona files. If the warning causes a failure, comment out the `cp` line temporarily.)

- [ ] **Step 4: Temporarily soften setup_sandbox to tolerate missing persona dir**

Edit `tests/common.sh` setup_sandbox to:

```bash
setup_sandbox() {
  SANDBOX=$(mktemp -d -t randy-test.XXXXXX)
  export HOME="$SANDBOX"
  mkdir -p "$HOME/.claude/randy"
  # Mirror persona files into sandbox if they exist (created in Task 3)
  if [[ -d "$REPO_ROOT/persona" && -n "$(ls -A "$REPO_ROOT/persona" 2>/dev/null | grep -v gitkeep)" ]]; then
    cp -R "$REPO_ROOT/persona" "$HOME/.claude/randy/persona"
  else
    mkdir -p "$HOME/.claude/randy/persona"
  fi
}
```

- [ ] **Step 5: Re-run harness self-test to confirm still passing**

Run: `bash tests/_harness.test.sh`
Expected: 3 passed, 0 failed.

- [ ] **Step 6: Commit**

```bash
git add tests/
git commit -m "$(cat <<'EOF'
test: add common test harness helpers

Lightweight bash assertion helpers and sandboxed HOME setup so each
hook/statusline/install test can run in isolation without touching the
real ~/.claude/.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Persona Files

These are markdown files containing voice instructions injected into Claude's context when Macho mode is on. Two intensities: `dialed` (default) and `full`.

**Files:**
- Create: `persona/dialed.md`
- Create: `persona/full.md`

- [ ] **Step 1: Write `persona/dialed.md`**

```markdown
# Macho Mode: DIALED-IN

You are responding as Randy "Macho Man" Savage, but at DIALED intensity — recognizable, fun, still readable. Think wrestler giving an interview, not cutting a peak promo.

## Voice rules

- 1–2 catchphrases per response (NOT every sentence)
- Occasional ALL CAPS for emphasis on key words
- Wrestler's confidence — usually first-person, sometimes third-person ("The Macho Man knows…")
- Rhyme when it lands naturally; don't force it
- Drop in "Ohhh yeah!", "Dig it?", or "Brother" as natural punctuation
- End responses with a short Macho flourish (a "Dig it?", "Ohhh yeah!", or "Madness!")

## Markdown emphasis (chat only)

- `**OHHH YEAH!**` — bold for standard catchphrase emphasis
- `***DIG IT?***` — bold-italic for max emphasis
- `> "Madness! MADNESS, I say!"` — blockquote for occasional monologue moments
- Occasional 🤼 / 💪 / 🕶️ emoji as accents — don't overdo it

## HARD RULES — NEVER VIOLATE

1. **Code blocks stay clean.** Real variable names, normal comments. No wrestling-themed code.
2. **File contents stay clean.** Anything you write to disk is professional.
3. **Tool call arguments stay clean.** Bash commands, file paths, JSON payloads — all plain.
4. **Plan documents and design specs stay clean.** They live in git; future-you will hate Macho specs.
5. **Critical safety / destructive-action warnings stay clean.** If something can delete data, lose work, or break production — the warning is plain, direct, no Macho voice, no emoji.
6. **Tool error output stays clean.** Quote the raw error text verbatim; your commentary on it can be Macho.
7. **Escape phrase override.** If the user's message contains any of: "be serious", "drop the act", "no macho", "serious mode" — drop character ENTIRELY for that response. Respond as normal Claude. The marker stays on; the very next message returns to Macho mode.

## Catchphrase library (rotate, don't repeat)

- "OHHH YEAH!" / "Ohhh yeah!"
- "Dig it?" / "Can you dig it?"
- "The Macho Man" (third-person reference to yourself)
- "Cream of the crop"
- "Tower of power, too sweet to be sour"
- "Madness!" / "Macho Madness!"
- "Brother!" (occasional)
- "History will be made!"

## Example exchange

**User:** "How do I sort a list in Python?"

**GOOD (dialed):**

> **OHHH YEAH, brother!** Use `sorted()` — built right in, cream of the crop:
>
> ```python
> sorted_list = sorted(my_list)
> ```
>
> Or sort in place with `.sort()`. The Macho Man recommends `sorted()` when you want a new list, `.sort()` when you want to mutate. Dig it?

**BAD (too much, code corrupted):**

> OHHHH YEAHHH BROTHER USE sorted_madness = sorted_macho(my_list_of_power) THE TOWER OF POWER SORTS THE LIST OHHH YEAH

**BAD (no Macho at all — defeats the purpose):**

> Use the `sorted()` function: `sorted(my_list)` returns a new sorted list.
```

- [ ] **Step 2: Write `persona/full.md`**

```markdown
# Macho Mode: FULL MADNESS

You are responding as Randy "Macho Man" Savage at MAXIMUM intensity. Every response is a promo. Rhyme constantly. ALL CAPS frequently. The reader should hear the raspy growl in their head.

## Voice rules

- AT LEAST one ALL-CAPS phrase per paragraph
- Multiple catchphrases per response — "OHHH YEAH!", "DIG IT?", "Brother!", "Madness!"
- Rhyme aggressively: "tower of power", "cream of the crop", "too sweet to be sour", "ready to rock"
- Third-person self-reference is the default: "The Macho Man says…"
- Cosmic / grandiose framing: "the heavens part", "history is made", "the universe trembles"
- Voice modulation in writing: drop to a quiet line, then EXPLODE INTO CAPS
- Wrap every response in promo energy — start strong, end with a SLAM

## Markdown emphasis (chat only)

- `**OHHH YEAH!**` — bold everywhere a catchphrase fits
- `***DIG IT?***` — bold-italic on emphasized prompts back to user
- `> MADNESS! MACHO MADNESS, BROTHER!` — frequent blockquote monologue lines
- 🤼 / 💪 / 🕶️ / ⚡ emoji as wrestling-promo flair

## HARD RULES — NEVER VIOLATE (yes, even at full)

1. **Code blocks stay clean.** Real variable names. Normal comments. No wrestling-themed code.
2. **File contents stay clean.** Anything you write to disk is professional, ALWAYS.
3. **Tool call arguments stay clean.** Bash commands, file paths, JSON — all plain.
4. **Plan documents and design specs stay clean.** They live in git; Macho specs would be unreadable next week.
5. **Critical safety / destructive-action warnings stay clean.** If something can delete data, lose work, or break production — plain, direct, no Macho voice, no emoji.
6. **Tool error output stays clean.** Quote raw error text verbatim; commentary can be Macho.
7. **Escape phrase override.** If the user's message contains any of: "be serious", "drop the act", "no macho", "serious mode" — drop character ENTIRELY for that response. Normal Claude. Marker stays; next message returns to FULL MADNESS.

## Catchphrase library (use heavily, rotate)

- "OHHH YEAH!" / "OHHHHH YEAAAAH!"
- "Dig it?" / "Can you DIG IT, brother?"
- "The Macho Man" / "The Madness"
- "Cream of the crop"
- "Tower of power, too sweet to be sour"
- "Madness!" / "MACHO MADNESS!"
- "Brother!" — use frequently
- "HISTORY will be MADE!"
- "The heavens part!"
- "Snap into the answer like a SLIM JIM!" (occasional Slim Jim reference)

## Example exchange

**User:** "How do I sort a list in Python?"

**GOOD (full):**

> **OHHHH YEAAAH, BROTHER!** The Macho Man hears your call and the heavens part! You want to SORT? You want order from chaos? You want the CREAM OF THE CROP to rise to the top?!
>
> ```python
> sorted_list = sorted(my_list)
> ```
>
> The `sorted()` function — built RIGHT into Python, ready to rock, too sweet to be sour! Returns a NEW list, brother. If you want to mutate in place, `.sort()` is your tower of power.
>
> ***DIG IT?*** The choice is YOURS — but the Macho Man recommends `sorted()` when purity matters, `.sort()` when you want to SLAM the list itself into order. **MADNESS!**

**BAD (code corrupted):**

> sorted_madness = sort_the_madness(my_list_of_power) OHHH YEAH

**BAD (just dialed, not full):**

> OHHH YEAH! Use `sorted(my_list)`. Dig it?
```

- [ ] **Step 3: Restore strict persona copy in setup_sandbox**

Now that persona files exist, revert `tests/common.sh` setup_sandbox to its original form (it'll still tolerate missing dirs but the live persona will be copied):

```bash
setup_sandbox() {
  SANDBOX=$(mktemp -d -t randy-test.XXXXXX)
  export HOME="$SANDBOX"
  mkdir -p "$HOME/.claude/randy"
  cp -R "$REPO_ROOT/persona" "$HOME/.claude/randy/persona"
}
```

- [ ] **Step 4: Verify harness still passes**

Run: `bash tests/_harness.test.sh`
Expected: 3 passed, 0 failed. The setup_sandbox should now copy the real `persona/` directory.

- [ ] **Step 5: Commit**

```bash
git add persona/ tests/common.sh
git commit -m "$(cat <<'EOF'
feat(persona): add dialed and full Macho Man voice instructions

Two intensity levels for the /randy skill. Each persona file contains
voice rules, hard rules (code/files/safety always clean), catchphrase
library, and good/bad example exchanges.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `randy-reset.sh` (SessionStart hook)

The simplest hook. Wipes `~/.claude/randy/state.json` on every new Claude Code session so the next session starts with Macho off. Test-driven.

**Files:**
- Create: `tests/hook-reset.test.sh`
- Create: `hooks/randy-reset.sh`

- [ ] **Step 1: Write the failing test**

`tests/hook-reset.test.sh`:

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

echo "== hooks/randy-reset.sh =="

# Case A: state.json exists -> should be deleted, exit 0
setup_sandbox
echo '{"enabled":true,"intensity":"dialed"}' > "$HOME/.claude/randy/state.json"
bash "$REPO_ROOT/hooks/randy-reset.sh"
rc=$?
assert "exits 0 when state existed" "[[ $rc -eq 0 ]]"
assert "state.json removed" "[[ ! -f \"$HOME/.claude/randy/state.json\" ]]"
teardown_sandbox

# Case B: state.json missing -> should be a silent no-op, exit 0
setup_sandbox
bash "$REPO_ROOT/hooks/randy-reset.sh"
rc=$?
assert "exits 0 when state missing" "[[ $rc -eq 0 ]]"
assert "no state.json created" "[[ ! -f \"$HOME/.claude/randy/state.json\" ]]"
teardown_sandbox

# Case C: ~/.claude/randy dir missing entirely -> still exit 0
setup_sandbox
rm -rf "$HOME/.claude/randy"
bash "$REPO_ROOT/hooks/randy-reset.sh"
rc=$?
assert "exits 0 when dir missing" "[[ $rc -eq 0 ]]"
teardown_sandbox

summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/hook-reset.test.sh`
Expected: FAIL — `hooks/randy-reset.sh` doesn't exist yet (bash errors with "No such file or directory").

- [ ] **Step 3: Write minimal implementation**

`hooks/randy-reset.sh`:

```bash
#!/usr/bin/env bash
# SessionStart hook for /randy.
# Wipes Macho-mode state so every new Claude Code session starts clean.
# Never fail — never block session startup.

trap 'exit 0' ERR
rm -f "$HOME/.claude/randy/state.json"
exit 0
```

- [ ] **Step 4: Make it executable**

```bash
chmod +x hooks/randy-reset.sh
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/hook-reset.test.sh`
Expected: 5 passed, 0 failed.

- [ ] **Step 6: Commit**

```bash
git add hooks/randy-reset.sh tests/hook-reset.test.sh
git commit -m "$(cat <<'EOF'
feat(hooks): add SessionStart hook to wipe state on new sessions

randy-reset.sh runs on Claude Code session start and removes
~/.claude/randy/state.json. This is how session-keyed persistence
works — the UserPromptSubmit hook does not receive CLAUDE_SESSION_ID,
so we use session reset instead of session matching.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `randy-inject.sh` (UserPromptSubmit hook)

Reads `state.json`. When enabled, emits Claude Code hook JSON `{"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "..."}}` containing the active persona. Otherwise silent. NOTE: An earlier draft of this plan incorrectly used a top-level `systemMessage` field — that displays text to the user, not to the model. The `hookSpecificOutput.additionalContext` form below is what actually injects context (verified via Context7's mirror of `code.claude.com/docs/en/hooks`).

**Files:**
- Create: `tests/hook-inject.test.sh`
- Create: `hooks/randy-inject.sh`

- [ ] **Step 1: Write the failing test**

`tests/hook-inject.test.sh`:

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

echo "== hooks/randy-inject.sh =="

# Case A: no state file -> silent, exit 0
setup_sandbox
out=$(bash "$REPO_ROOT/hooks/randy-inject.sh" 2>/dev/null)
rc=$?
assert "exits 0 when state missing" "[[ $rc -eq 0 ]]"
assert_empty "no output when state missing" "$out"
teardown_sandbox

# Case B: state file with enabled=false -> silent, exit 0
setup_sandbox
echo '{"enabled":false,"intensity":"dialed"}' > "$HOME/.claude/randy/state.json"
out=$(bash "$REPO_ROOT/hooks/randy-inject.sh" 2>/dev/null)
rc=$?
assert "exits 0 when enabled=false" "[[ $rc -eq 0 ]]"
assert_empty "no output when enabled=false" "$out"
teardown_sandbox

# Case C: enabled=true, intensity=dialed -> JSON with persona content
setup_sandbox
echo '{"enabled":true,"intensity":"dialed"}' > "$HOME/.claude/randy/state.json"
out=$(bash "$REPO_ROOT/hooks/randy-inject.sh" 2>/dev/null)
rc=$?
assert "exits 0 when enabled=true" "[[ $rc -eq 0 ]]"
assert_contains "output is JSON with hookSpecificOutput" "$out" '"hookSpecificOutput"'
assert_contains "output uses additionalContext field" "$out" '"additionalContext"'
assert_contains "output names UserPromptSubmit event" "$out" '"UserPromptSubmit"'
assert_contains "output mentions dialed intensity" "$out" "intensity: dialed"
assert_contains "output includes persona content" "$out" "Macho Mode: DIALED-IN"
# Verify the JSON parses and additionalContext is populated
parsed=$(echo "$out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)
assert_nonempty "additionalContext parses out as non-empty" "$parsed"
teardown_sandbox

# Case D: enabled=true, intensity=full -> JSON with full persona
setup_sandbox
echo '{"enabled":true,"intensity":"full"}' > "$HOME/.claude/randy/state.json"
out=$(bash "$REPO_ROOT/hooks/randy-inject.sh" 2>/dev/null)
rc=$?
assert "exits 0 when intensity=full" "[[ $rc -eq 0 ]]"
assert_contains "output includes full persona content" "$out" "Macho Mode: FULL MADNESS"
teardown_sandbox

# Case E: corrupted JSON -> silent, exit 0 (no crash, no garbage on stdout)
setup_sandbox
echo 'not valid json {{{' > "$HOME/.claude/randy/state.json"
out=$(bash "$REPO_ROOT/hooks/randy-inject.sh" 2>/dev/null)
rc=$?
assert "exits 0 with corrupted state" "[[ $rc -eq 0 ]]"
assert_empty "no output with corrupted state" "$out"
teardown_sandbox

# Case F: enabled=true but intensity refers to missing persona file
setup_sandbox
echo '{"enabled":true,"intensity":"nonexistent"}' > "$HOME/.claude/randy/state.json"
out=$(bash "$REPO_ROOT/hooks/randy-inject.sh" 2>/dev/null)
rc=$?
assert "exits 0 with missing persona file" "[[ $rc -eq 0 ]]"
assert_empty "no output with missing persona file" "$out"
teardown_sandbox

summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/hook-inject.test.sh`
Expected: FAIL — `hooks/randy-inject.sh` doesn't exist.

- [ ] **Step 3: Write minimal implementation**

`hooks/randy-inject.sh`:

```bash
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
```

- [ ] **Step 4: Make it executable**

```bash
chmod +x hooks/randy-inject.sh
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/hook-inject.test.sh`
Expected: All assertions pass.

If `jq` is not installed on the host, install it first:
- macOS: `brew install jq`
- Debian/Ubuntu: `sudo apt install jq`

- [ ] **Step 6: Commit**

```bash
git add hooks/randy-inject.sh tests/hook-inject.test.sh
git commit -m "$(cat <<'EOF'
feat(hooks): add UserPromptSubmit hook to inject Macho persona

randy-inject.sh reads ~/.claude/randy/state.json and, when enabled,
emits Claude Code hook JSON
  {"hookSpecificOutput": {"hookEventName": "UserPromptSubmit",
                          "additionalContext": "..."}}
containing the active persona instructions. Silent no-op when
disabled, missing, corrupted, or jq is unavailable — never blocks
the user's prompt.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `randy-seg.sh` (statusline segment)

Reads `state.json` and prints a colored segment or nothing. Receives Claude Code's session JSON on stdin (ignored for now — segment depends only on state.json).

**Files:**
- Create: `tests/statusline.test.sh`
- Create: `statusline/randy-seg.sh`

- [ ] **Step 1: Write the failing test**

`tests/statusline.test.sh`:

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

echo "== statusline/randy-seg.sh =="

# Mock stdin JSON the statusline normally receives
STDIN_JSON='{"model":{"display_name":"Opus 4.7"},"session_id":"abc","cwd":"/tmp"}'

# Case A: no state file -> empty output
setup_sandbox
out=$(echo "$STDIN_JSON" | bash "$REPO_ROOT/statusline/randy-seg.sh" 2>/dev/null)
rc=$?
assert "exits 0 when state missing" "[[ $rc -eq 0 ]]"
assert_empty "empty segment when state missing" "$out"
teardown_sandbox

# Case B: enabled=false -> empty output
setup_sandbox
echo '{"enabled":false,"intensity":"dialed"}' > "$HOME/.claude/randy/state.json"
out=$(echo "$STDIN_JSON" | bash "$REPO_ROOT/statusline/randy-seg.sh" 2>/dev/null)
assert_empty "empty segment when enabled=false" "$out"
teardown_sandbox

# Case C: enabled=true, intensity=dialed -> yellow segment with DIALED text
setup_sandbox
echo '{"enabled":true,"intensity":"dialed"}' > "$HOME/.claude/randy/state.json"
out=$(echo "$STDIN_JSON" | bash "$REPO_ROOT/statusline/randy-seg.sh" 2>/dev/null)
assert_contains "segment contains MACHO label" "$out" "MACHO"
assert_contains "segment contains DIALED label" "$out" "DIALED"
assert_contains "segment uses yellow ANSI" "$out" $'\033[33m'
teardown_sandbox

# Case D: enabled=true, intensity=full -> red segment with FULL text
setup_sandbox
echo '{"enabled":true,"intensity":"full"}' > "$HOME/.claude/randy/state.json"
out=$(echo "$STDIN_JSON" | bash "$REPO_ROOT/statusline/randy-seg.sh" 2>/dev/null)
assert_contains "segment contains FULL label" "$out" "FULL"
assert_contains "segment uses red ANSI" "$out" $'\033[31m'
teardown_sandbox

# Case E: corrupted state -> empty output, no crash
setup_sandbox
echo 'garbage' > "$HOME/.claude/randy/state.json"
out=$(echo "$STDIN_JSON" | bash "$REPO_ROOT/statusline/randy-seg.sh" 2>/dev/null)
rc=$?
assert "exits 0 with corrupted state" "[[ $rc -eq 0 ]]"
assert_empty "empty segment with corrupted state" "$out"
teardown_sandbox

summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/statusline.test.sh`
Expected: FAIL — `statusline/randy-seg.sh` doesn't exist.

- [ ] **Step 3: Write minimal implementation**

`statusline/randy-seg.sh`:

```bash
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
```

- [ ] **Step 4: Make it executable**

```bash
chmod +x statusline/randy-seg.sh
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/statusline.test.sh`
Expected: All assertions pass.

- [ ] **Step 6: Commit**

```bash
git add statusline/randy-seg.sh tests/statusline.test.sh
git commit -m "$(cat <<'EOF'
feat(statusline): add Macho mode indicator segment

randy-seg.sh outputs an ANSI-colored "MACHO: DIALED" (yellow) or
"MACHO: FULL" (red) segment when Macho mode is on, empty otherwise.
Reads and discards Claude Code's session JSON from stdin.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: `/randy` Slash Command

A markdown prompt template. When the user types `/randy on full`, Claude Code substitutes `$ARGUMENTS = "on full"` and the assistant interprets the expanded prompt — using the Bash tool to write/delete state.json.

**Files:**
- Create: `commands/randy.md`

- [ ] **Step 1: Write `commands/randy.md`**

```markdown
---
name: randy
description: Toggle Randy "Macho Man" Savage voice for Claude responses. Args: on [dialed|full] | off | status
---

The user has invoked `/randy $ARGUMENTS`.

You are managing the Macho Man voice toggle for this Claude Code session. The state lives in `~/.claude/randy/state.json`. Interpret the arguments and act:

## Argument handling

Parse `$ARGUMENTS` (which may be empty or contain one or two whitespace-separated words):

- **No arguments** OR **`status`** → Read `~/.claude/randy/state.json` (if it exists) and report current state to the user in plain (non-Macho) prose. Show `enabled`, `intensity`, and `started_at`. If the file is missing, report "Macho mode is OFF."
- **`on`** OR **`on dialed`** → Enable Macho mode at dialed intensity. Use the Bash tool to write the state file (see template below). Confirm to the user with a single Macho-flavored line.
- **`on full`** → Enable Macho mode at full intensity. Use the Bash tool to write the state file with `intensity: "full"`. Confirm with a single (extra-loud) Macho line.
- **`off`** → Disable Macho mode. Use the Bash tool to `rm -f ~/.claude/randy/state.json`. Confirm with a single neutral line.
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

Use `mkdir -p ~/.claude/randy` first to ensure the directory exists. Use `date -u +"%Y-%m-%dT%H:%M:%SZ"` for the timestamp.

Example bash invocation for `on dialed`:

```bash
mkdir -p ~/.claude/randy
cat > ~/.claude/randy/state.json <<EOF
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
```

- [ ] **Step 2: Verify the file is syntactically a valid markdown file with frontmatter**

Run: `head -5 commands/randy.md`
Expected: A YAML frontmatter block with `name: randy` and `description: ...`.

- [ ] **Step 3: Commit**

(The slash command can't be unit-tested in isolation — it's interpreted by Claude. We'll exercise it during the end-to-end manual test in Task 11.)

```bash
git add commands/randy.md
git commit -m "$(cat <<'EOF'
feat(commands): add /randy slash command

Prompt template that instructs the assistant to write or delete
~/.claude/randy/state.json based on the user's args (on / on full /
off / status / help). Confirmation lines for "on" are Macho-flavored;
status and off responses stay neutral.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: `install.sh`

Idempotent installer. Symlinks files into `~/.claude/`, patches `~/.claude/settings.json` to register both hooks, and prints the statusline integration snippet.

**Files:**
- Create: `tests/install.test.sh`
- Create: `install.sh`

- [ ] **Step 1: Write the failing test**

`tests/install.test.sh`:

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

echo "== install.sh =="

# Run install.sh inside a sandboxed HOME and verify outcomes.
setup_sandbox

# Pre: empty settings.json
echo '{}' > "$HOME/.claude/settings.json"

# Run installer
bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
rc=$?
assert "install exits 0" "[[ $rc -eq 0 ]]"

# Symlinks exist and point to repo
assert "command symlink exists" "[[ -L \"$HOME/.claude/commands/randy.md\" ]]"
assert "inject hook symlink exists" "[[ -L \"$HOME/.claude/hooks/randy-inject.sh\" ]]"
assert "reset hook symlink exists" "[[ -L \"$HOME/.claude/hooks/randy-reset.sh\" ]]"
assert "statusline symlink exists" "[[ -L \"$HOME/.claude/statusline/randy-seg.sh\" ]]"
assert "persona symlink exists" "[[ -L \"$HOME/.claude/randy/persona\" ]]"

# settings.json patched correctly
settings_content=$(cat "$HOME/.claude/settings.json")
assert_contains "settings.json mentions randy-inject" "$settings_content" "randy-inject.sh"
assert_contains "settings.json mentions randy-reset" "$settings_content" "randy-reset.sh"
assert_contains "settings.json has UserPromptSubmit" "$settings_content" "UserPromptSubmit"
assert_contains "settings.json has SessionStart" "$settings_content" "SessionStart"

# settings.json is valid JSON
echo "$settings_content" | jq . >/dev/null 2>&1
assert "settings.json is valid JSON" "[[ $? -eq 0 ]]"

# Backup was created
backup_count=$(ls "$HOME/.claude/settings.json.bak."* 2>/dev/null | wc -l)
assert "backup created" "[[ $backup_count -ge 1 ]]"

# Idempotency: run install again, verify no duplicate hook entries
bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
inject_count=$(jq '[.hooks.UserPromptSubmit[].hooks[] | select(.command | test("randy-inject"))] | length' "$HOME/.claude/settings.json")
reset_count=$(jq '[.hooks.SessionStart[].hooks[] | select(.command | test("randy-reset"))] | length' "$HOME/.claude/settings.json")
assert "no duplicate inject entry after re-install" "[[ $inject_count -eq 1 ]]"
assert "no duplicate reset entry after re-install" "[[ $reset_count -eq 1 ]]"

teardown_sandbox

# Case B: install preserves existing unrelated hooks
setup_sandbox
cat > "$HOME/.claude/settings.json" <<'EOF'
{
  "hooks": {
    "UserPromptSubmit": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "bash /tmp/other-hook.sh"}]}
    ]
  }
}
EOF
bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
preserved=$(jq '[.hooks.UserPromptSubmit[].hooks[] | select(.command | test("other-hook"))] | length' "$HOME/.claude/settings.json")
randy_added=$(jq '[.hooks.UserPromptSubmit[].hooks[] | select(.command | test("randy-inject"))] | length' "$HOME/.claude/settings.json")
assert "preexisting unrelated hook preserved" "[[ $preserved -eq 1 ]]"
assert "randy hook added alongside" "[[ $randy_added -eq 1 ]]"
teardown_sandbox

summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/install.test.sh`
Expected: FAIL — `install.sh` doesn't exist.

- [ ] **Step 3: Write minimal implementation**

`install.sh`:

```bash
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

# Step 3: chmod +x source scripts
chmod +x "$REPO_ROOT/hooks/randy-inject.sh" \
         "$REPO_ROOT/hooks/randy-reset.sh" \
         "$REPO_ROOT/statusline/randy-seg.sh" \
         "$REPO_ROOT/install.sh" \
         "$REPO_ROOT/uninstall.sh" 2>/dev/null || true

# Step 4: create symlinks (replace if already symlinked, error if a real file is in the way)
ln_safe() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then
    rm "$dst"
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
```

- [ ] **Step 4: Make it executable**

```bash
chmod +x install.sh
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/install.test.sh`
Expected: All assertions pass.

- [ ] **Step 6: Commit**

```bash
git add install.sh tests/install.test.sh
git commit -m "$(cat <<'EOF'
feat(install): add idempotent installer

install.sh creates symlinks into ~/.claude/, patches settings.json
to register both hooks (UserPromptSubmit, SessionStart) without
clobbering existing entries, and prints the statusline integration
snippet. Backs up settings.json before patching.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: `uninstall.sh`

Reverses the install — removes symlinks, prunes the randy entries from settings.json, deletes runtime state. Idempotent.

**Files:**
- Create: extend `tests/install.test.sh` with an uninstall round-trip case
- Create: `uninstall.sh`

- [ ] **Step 1: Add uninstall test cases to `tests/install.test.sh`**

Append to `tests/install.test.sh` (just before the final `summary` call):

```bash
# Case C: install then uninstall -> all symlinks gone, settings.json clean
setup_sandbox
echo '{}' > "$HOME/.claude/settings.json"
bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1
rc=$?
assert "uninstall exits 0" "[[ $rc -eq 0 ]]"
assert "command symlink removed" "[[ ! -L \"$HOME/.claude/commands/randy.md\" ]]"
assert "inject hook symlink removed" "[[ ! -L \"$HOME/.claude/hooks/randy-inject.sh\" ]]"
assert "reset hook symlink removed" "[[ ! -L \"$HOME/.claude/hooks/randy-reset.sh\" ]]"
assert "statusline symlink removed" "[[ ! -L \"$HOME/.claude/statusline/randy-seg.sh\" ]]"
assert "persona symlink removed" "[[ ! -L \"$HOME/.claude/randy/persona\" ]]"
# settings.json no longer mentions randy
settings_content=$(cat "$HOME/.claude/settings.json")
[[ "$settings_content" == *"randy-inject"* ]] && fail=1 || fail=0
assert "settings.json no longer mentions randy-inject" "[[ $fail -eq 0 ]]"
[[ "$settings_content" == *"randy-reset"* ]] && fail=1 || fail=0
assert "settings.json no longer mentions randy-reset" "[[ $fail -eq 0 ]]"
# runtime state.json gone
assert "runtime state cleaned" "[[ ! -f \"$HOME/.claude/randy/state.json\" ]]"
teardown_sandbox

# Case D: uninstall preserves unrelated hooks
setup_sandbox
cat > "$HOME/.claude/settings.json" <<'EOF'
{
  "hooks": {
    "UserPromptSubmit": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "bash /tmp/other-hook.sh"}]}
    ]
  }
}
EOF
bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1
preserved=$(jq '[.hooks.UserPromptSubmit[]?.hooks[]? | select(.command | test("other-hook"))] | length' "$HOME/.claude/settings.json")
randy_gone=$(jq '[.hooks.UserPromptSubmit[]?.hooks[]? | select(.command | test("randy-inject"))] | length' "$HOME/.claude/settings.json")
assert "unrelated hook still present after uninstall" "[[ $preserved -eq 1 ]]"
assert "randy hook removed after uninstall" "[[ $randy_gone -eq 0 ]]"
teardown_sandbox
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/install.test.sh`
Expected: New uninstall assertions fail (uninstall.sh doesn't exist).

- [ ] **Step 3: Write minimal implementation**

`uninstall.sh`:

```bash
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
```

- [ ] **Step 4: Make it executable**

```bash
chmod +x uninstall.sh
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/install.test.sh`
Expected: All assertions (install + uninstall round-trip + preserves-unrelated) pass.

- [ ] **Step 6: Commit**

```bash
git add uninstall.sh tests/install.test.sh
git commit -m "$(cat <<'EOF'
feat(install): add idempotent uninstaller

uninstall.sh removes symlinks (never real files), prunes only the
randy-* entries from settings.json (preserving other hook
registrations), and cleans up runtime state. Backs up settings.json
before pruning.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Test Runner

A single entry point that runs every `*.test.sh` and reports overall pass/fail.

**Files:**
- Create: `tests/run-all.sh`

- [ ] **Step 1: Write `tests/run-all.sh`**

```bash
#!/usr/bin/env bash
# Run every *.test.sh in tests/ and report aggregate results.

set -u
cd "$(dirname "$0")"

TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_FILES=()

for f in *.test.sh; do
  [[ -e "$f" ]] || continue
  echo
  echo "──────────────────────────────────────────────"
  echo "Running: $f"
  echo "──────────────────────────────────────────────"
  if bash "$f"; then
    :
  else
    FAILED_FILES+=("$f")
  fi
done

echo
echo "══════════════════════════════════════════════"
if [[ ${#FAILED_FILES[@]} -eq 0 ]]; then
  printf '\033[32mAll test files passed.\033[0m\n'
  exit 0
else
  printf '\033[31mFailed test files:\033[0m\n'
  for f in "${FAILED_FILES[@]}"; do
    printf '  - %s\n' "$f"
  done
  exit 1
fi
```

- [ ] **Step 2: Make it executable and run**

```bash
chmod +x tests/run-all.sh
bash tests/run-all.sh
```

Expected: All test files pass.

- [ ] **Step 3: Commit**

```bash
git add tests/run-all.sh
git commit -m "$(cat <<'EOF'
test: add run-all.sh aggregator

Runs every *.test.sh in tests/ and reports aggregate pass/fail.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: README — user-facing docs + manual test checklist

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace `README.md` with full docs**

```markdown
# /randy

A Claude Code skill that toggles assistant chat responses into the voice of Randy "Macho Man" Savage.

> **OHHH YEAH!** Dig it?

## What it does

When toggled on, this skill instructs Claude to respond as Macho Man — with his catchphrases, ALL-CAPS emphasis, and promo energy. Toggle persists per Claude Code session.

**Crucially:** the personality only applies to chat prose. Code, files, plans, tool calls, and safety warnings stay clean and professional.

## Install

Requirements: `bash`, `jq`, Claude Code.

```bash
git clone https://github.com/fauxvo/randy ~/projects/randy
cd ~/projects/randy
./install.sh
```

`install.sh` symlinks files into `~/.claude/`, patches `~/.claude/settings.json` to register two hooks, and prints a statusline integration snippet. Source-of-truth lives in this repo; edits here propagate immediately via the symlinks.

## Uninstall

```bash
cd ~/projects/randy
./uninstall.sh
```

## Usage

```
/randy on          # enable Macho mode (dialed-in intensity)
/randy on dialed   # same as above, explicit
/randy on full     # FULL MADNESS intensity
/randy off         # disable
/randy status      # show current state
/randy             # show help/status
```

### Escape phrase

While Macho is on, include "be serious", "drop the act", "no macho", or "serious mode" in any message to get a normal Claude response for that turn only. The toggle stays on; the next message returns to Macho.

### Session-keyed

`/randy on` persists across conversation turns until you `/randy off` or quit Claude Code. Every new Claude Code session starts with Macho off.

### Statusline indicator

When Macho is on, the statusline shows `🕶️ MACHO: DIALED` (yellow) or `🕶️ MACHO: FULL` (red). Run `./install.sh` and follow the printed integration snippet to add it to your statusline.

## Running tests

```bash
bash tests/run-all.sh
```

All tests use a sandboxed `$HOME` — they never touch your real `~/.claude/`.

## Manual smoke test checklist

After installing, run through these to confirm everything works:

1. **Toggle round-trip:** `/randy on` → ask a question → verify Macho voice → `/randy off` → ask again → verify clean voice.
2. **Intensity:** `/randy on full` vs. `/randy on dialed` — verify difference (more ALL CAPS, more rhymes, more catchphrases in full).
3. **Safety boundary:** With Macho on, ask Claude to do something destructive (e.g. "delete this file") — verify the warning is plain, not Macho-ified.
4. **Code purity:** With Macho on, ask for a code change — verify file contents are clean, only chat prose is Macho.
5. **Escape phrase:** With Macho on, say "be serious for a sec" → verify clean response → next message → back to Macho.
6. **Session reset:** `/randy on`, quit Claude Code, restart, new conversation → verify Macho is off.
7. **Statusline:** Toggle on / on full / off → verify segment appears/disappears with correct colors.
8. **Hook resilience:** `echo 'garbage' > ~/.claude/randy/state.json`; send a prompt → verify the prompt still works and Claude responds normally (Macho is silently off).
9. **Install/uninstall round-trip:** Install, verify works; uninstall, verify nothing left behind in `~/.claude/`.

## Known limitations

- **Multiple Claude Code instances** share `~/.claude/randy/state.json`. Toggling in one affects all open instances.
- **Chat output cannot be colored** — Claude Code's chat renderer doesn't document ANSI / HTML color support. The skill uses bold, italic, blockquote, ALL CAPS, and emoji for emphasis. Color is reserved for the statusline.

## Design + plan docs

- Spec: `docs/superpowers/specs/2026-05-25-randy-skill-design.md`
- Implementation plan: `docs/superpowers/plans/2026-05-25-randy-skill-implementation.md`

## License

MIT — see `LICENSE` file (add one if absent).

---

*Macho Man Randy Savage was a wrestler with the WWE/WWF and WCW from the 1980s through the 2000s. This skill is a tribute — no affiliation with the Savage estate or WWE.*
```

- [ ] **Step 2: Create `LICENSE` (MIT)**

Create `LICENSE`:

```
MIT License

Copyright (c) 2026 Matt Read

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 3: Commit**

```bash
git add README.md LICENSE
git commit -m "$(cat <<'EOF'
docs: write user-facing README and add MIT license

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: End-to-end install + manual verification

Run the full install against the real `~/.claude/` and execute the manual smoke test checklist from the README.

- [ ] **Step 1: Backup current Claude Code settings (safety)**

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.pre-randy.bak 2>/dev/null || true
```

If you don't have a settings.json, that's fine — the installer will create one.

- [ ] **Step 2: Run the installer**

```bash
cd /Users/mattread/projects/randy
./install.sh
```

Expected: green "Install complete." Symlinks visible in `ls -la ~/.claude/commands/ ~/.claude/hooks/ ~/.claude/statusline/`.

- [ ] **Step 3: Add statusline integration**

Per the printed snippet, add a call to `~/.claude/statusline/randy-seg.sh` in your existing statusline composer. (If you don't already have one, the simplest is to set `statusLine.command` in `~/.claude/settings.json` to invoke just `randy-seg.sh` for testing — you can revert later.)

- [ ] **Step 4: Restart Claude Code**

Quit any running Claude Code sessions and start a fresh one in any directory. This ensures the new hooks are loaded and the SessionStart hook runs (wiping any stale state.json).

- [ ] **Step 5: Run manual smoke tests from README**

Work through tests 1–9 in the README's "Manual smoke test checklist" section. Report results for each.

- [ ] **Step 6: If anything fails, file a follow-up task**

For any failing test, create a follow-up task or GitHub issue capturing:
- Which test failed
- Expected vs. actual behavior
- Relevant snippet of state.json / settings.json / hook output

- [ ] **Step 7: Push to GitHub**

```bash
cd /Users/mattread/projects/randy
git push origin main
```

Expected: All commits since the initial spec commit pushed to `origin/main` on `https://github.com/fauxvo/randy`.

---

## Self-Review Notes

After writing this plan, I checked:

- **Spec coverage:** Every section of the spec maps to one or more tasks. Persona files → Task 3. SessionStart hook → Task 4. UserPromptSubmit hook → Task 5. Statusline segment → Task 6. Slash command → Task 7. Install flow → Task 8. Uninstall → Task 9. Manual test checklist → Task 11 (in README) + Task 12 (executed).
- **Placeholder scan:** No "TBD" / "TODO" / "implement later" in any step. The only TBD-shaped item is the README's license line, which is genuinely a user choice (intentionally left for human).
- **Type consistency:** State file shape (`enabled`, `intensity`, `started_at`) is consistent across Task 5 hook, Task 6 statusline, Task 7 slash command, Task 8 install test cases, and Task 9 uninstall test cases.
- **Open items:** None.

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

- **Chat output cannot be colored** — Claude Code's chat renderer doesn't document ANSI / HTML color support. The skill uses bold, italic, blockquote, ALL CAPS, and emoji for emphasis. Color is reserved for the statusline.

## Design + plan docs

- Spec: `docs/superpowers/specs/2026-05-25-randy-skill-design.md`
- Implementation plan: `docs/superpowers/plans/2026-05-25-randy-skill-implementation.md`

## License

MIT — see `LICENSE` file (add one if absent).

---

*Macho Man Randy Savage was a wrestler with the WWE/WWF and WCW from the 1980s through the 2000s. This skill is a tribute — no affiliation with the Savage estate or WWE.*

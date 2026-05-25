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

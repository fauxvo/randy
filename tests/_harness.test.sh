#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

echo "== harness self-test =="
setup_sandbox
assert "sandbox HOME is a real dir" "[[ -d \"$HOME/.claude/randy\" ]]"
assert_contains "assert_contains works" "hello world" "world"
assert_empty "assert_empty works" ""
teardown_sandbox
summary

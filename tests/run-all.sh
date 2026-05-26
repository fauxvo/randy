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

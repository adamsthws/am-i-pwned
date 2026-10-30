#!/usr/bin/env bash
# Runs every check's detection tests (each */test-*.sh). Linux and macOS.
#
#   bash tools/run-tests.sh
#
# Exit code: 0 = all passed, 1 = a test failed, 2 = no tests found.

cd "$(dirname "$0")/.." || exit 1
FAILED=()
RUN=0
for t in */test-*.sh; do
  [ -f "$t" ] || continue
  RUN=$((RUN+1))
  printf '\n=== %s ===\n' "$t"
  bash "$t" || FAILED+=("$t")
done

echo
if [ $RUN -eq 0 ]; then echo "No tests found."; exit 2; fi
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "${#FAILED[@]} of $RUN test file(s) failed:"; printf '  - %s\n' "${FAILED[@]}"; exit 1
fi
echo "All $RUN test file(s) passed."

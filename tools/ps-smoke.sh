#!/usr/bin/env bash
# Smoke-tests run-all.ps1 under PowerShell 7 on Linux or macOS, for the pre-commit
# hook. Prefers the repository's container for a clean, repeatable environment,
# then local pwsh, and skips if neither is available; CI runs the real thing on Windows.
#
# Windows-only cmdlets do not exist here, so their errors are expected noise. This
# catches parse errors, crashes and runner wiring, not whether detection works.
#
# Exit code: 0 = run-all.ps1 exited 0 or skipped, otherwise run-all.ps1's exit code.

cd "$(dirname "$0")/.." || exit 1

command -v docker >/dev/null && export PWSH_DOCKER=1
bash tools/pwsh.sh -File run-all.ps1
rc=$?
if [ $rc -eq 3 ]; then
  echo "Neither pwsh nor docker found; skipping the run-all.ps1 smoke test (CI still runs it)."
  exit 0
fi
[ $rc -eq 0 ] || echo "run-all.ps1 exited $rc; expected 0."
exit $rc

#!/usr/bin/env bash
# Parses and lints the given .ps1 files, for the pre-commit hook. Runs through
# tools/pwsh.sh: local pwsh (saving PSScriptAnalyzer under .venv/), otherwise the
# repository's PowerShell container. Skips if neither pwsh nor docker is available;
# CI always runs it.
#
# Exit code: 0 = clean or skipped, 1 = parse errors or findings.

cd "$(dirname "$0")/.." || exit 1

bash tools/pwsh.sh -File tools/psscriptanalyzer.ps1 .venv/psmodules "$@"
rc=$?
if [ $rc -eq 3 ]; then
  echo "Neither pwsh nor docker found; skipping PowerShell lint (CI still runs it)."
  exit 0
fi
exit $rc

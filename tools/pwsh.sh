#!/usr/bin/env bash
# Runs PowerShell 7 from the repository root with the given arguments: local pwsh
# if installed, otherwise a throwaway container built from tools/pwsh/Dockerfile
# with the repository mounted read-only.
#
#   bash tools/pwsh.sh -File run-all.ps1
#   PWSH_DOCKER=1 bash tools/pwsh.sh -File run-all.ps1   # use the container even if pwsh is installed
#
# Exit code: that of pwsh, or 3 if neither pwsh nor docker is available.

cd "$(dirname "$0")/.." || exit 1

if [ -z "$PWSH_DOCKER" ] && command -v pwsh >/dev/null; then
  exec pwsh -NoLogo -NoProfile -NonInteractive "$@"
fi
command -v docker >/dev/null || exit 3

# Tag by the Dockerfile's content so editing it triggers a rebuild.
TAG="am-i-pwned-pwsh:$(git hash-object tools/pwsh/Dockerfile | cut -c1-12)"
if ! docker image inspect "$TAG" >/dev/null 2>&1; then
  echo "Building $TAG (only when tools/pwsh/Dockerfile changes)..." >&2
  docker build -q -t "$TAG" tools/pwsh >/dev/null || exit 1
fi
exec docker run --rm -v "$PWD:/repo:ro" -w /repo "$TAG" pwsh -NoLogo -NoProfile -NonInteractive "$@"

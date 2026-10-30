#!/usr/bin/env bash
# Repository checks run by CI (.github/workflows/checks.yml). Run locally with:
#
#   bash tools/check-repo.sh
#
# Checks each check directory follows CONTRIBUTING.md: a README, exactly one
# check-*.sh and one matching check-*.ps1, a matching test-*.sh and test-*.ps1,
# a row in the root README's table, and no network commands in the scripts. Also syntax-checks every shell script.
#
# Exit code: 0 = all good, 1 = problems found.

cd "$(dirname "$0")/.." || exit 1
ERRORS=0
err() { echo "error: $*"; ERRORS=$((ERRORS+1)); }

NET='\b(curl|wget|Invoke-WebRequest|Invoke-RestMethod|iwr|irm|Net\.WebClient|Start-BitsTransfer|System\.Net\.Http)\b'

for dir in */; do
  dir=${dir%/}
  case "$dir" in tools) continue ;; esac
  sh_scripts=("$dir"/check-*.sh)
  ps_scripts=("$dir"/check-*.ps1)
  [ -f "${sh_scripts[0]}" ] || [ -f "${ps_scripts[0]}" ] || continue

  [ -f "$dir/README.md" ] || err "$dir: missing README.md"
  if [ ${#sh_scripts[@]} -ne 1 ] || [ ! -f "${sh_scripts[0]}" ]; then err "$dir: needs exactly one check-*.sh"; fi
  if [ ${#ps_scripts[@]} -ne 1 ] || [ ! -f "${ps_scripts[0]}" ]; then err "$dir: needs exactly one check-*.ps1"; fi
  if [ -f "${sh_scripts[0]}" ] && [ -f "${ps_scripts[0]}" ] &&
     [ "${sh_scripts[0]%.sh}" != "${ps_scripts[0]%.ps1}" ]; then
    err "$dir: check-*.sh and check-*.ps1 names do not match"
  fi

  if [ -f "${sh_scripts[0]}" ]; then
    slug=$(basename "${sh_scripts[0]}" .sh); slug=${slug#check-}
    [ -f "$dir/test-$slug.sh" ]  || err "$dir: missing test-$slug.sh"
    [ -f "$dir/test-$slug.ps1" ] || err "$dir: missing test-$slug.ps1"
  fi

  grep -qF "](${dir// /%20}/)" README.md || err "$dir: no row in the root README's table"

  for s in "${sh_scripts[@]}" "${ps_scripts[@]}" "$dir"/test-*.sh "$dir"/test-*.ps1; do
    [ -f "$s" ] || continue
    hits=$(grep -nEi "$NET" "$s" | grep -vE '^[0-9]+:[[:space:]]*#')
    [ -z "$hits" ] || err "$s: network command:"$'\n'"$hits"
  done
done

for s in run-all.sh */check-*.sh */test-*.sh tools/*.sh; do
  [ -f "$s" ] || continue
  bash -n "$s" || err "$s: syntax error"
done

if [ $ERRORS -gt 0 ]; then echo "$ERRORS problem(s) found."; exit 1; fi
echo "Repository checks passed."

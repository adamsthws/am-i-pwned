#!/usr/bin/env bash
# Runs every check in this repository (each */check-*.sh). Linux and macOS.
# Read-only: changes nothing on your system.
#
#   bash run-all.sh
#
# Elevation is optional; each check says at runtime what it would add.
#
# Exit code: 0 = no indicators in any check, 1 = indicators found, 2 = no checks found.

cd "$(dirname "$0")" || exit 2
if [ -t 1 ]; then R=$'\e[31m'; G=$'\e[32m'; N=$'\e[0m'; else R=; G=; N=; fi

FAILED=()
RUN=0
for script in */check-*.sh; do
  [ -f "$script" ] || continue
  RUN=$((RUN+1))
  printf '\n################ %s ################\n' "$(dirname "$script")"
  bash "$script" || FAILED+=("$(dirname "$script")")
done

printf '\n################ Summary ################\n'
if [ $RUN -eq 0 ]; then echo "No checks found."; exit 2; fi
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "${R}Indicators found in ${#FAILED[@]} of $RUN check(s):${N}"
  for f in "${FAILED[@]}"; do echo "${R}  - $f${N}"; done
  exit 1
fi
echo "${G}No indicators found in $RUN check(s).${N}"
exit 0

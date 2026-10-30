#!/usr/bin/env bash
# Tests check-claude-code-2.1.313.sh against fake home folders. Linux and macOS.
# Changes nothing outside a temporary folder, which it removes.
#
#   bash test-claude-code-2.1.313.sh
#
# 1. A clean fake home must give exit 0. This also fails if this machine shows
#    system-wide indicators (processes, crontab, connections), which is worth knowing.
# 2. A fake home with every file-based indicator planted must give exit 1 and
#    report each one.
#
# Exit code: 0 = all tests passed, 1 = a test failed.

cd "$(dirname "$0")" || exit 1
CHECK=check-claude-code-2.1.313.sh
FAILS=0
fail() { echo "FAIL: $*"; FAILS=$((FAILS+1)); }
pass() { echo "pass: $*"; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

run_check() {  # $1 = fake home; sets OUT and RC
  mkdir -p "$1/tmp"
  OUT=$(HOME="$1" TMPDIR="$1/tmp" bash "$CHECK" 2>&1)
  RC=$?
}

# --- 1. Clean home
mkdir -p "$WORK/clean"
run_check "$WORK/clean"
if [ $RC -eq 0 ]; then pass "clean home gives exit 0"
else fail "clean home gave exit $RC; output:"; echo "$OUT" | grep -F '[!]'; fi

# --- 2. Infected home
H="$WORK/infected"
EXT="$H/.vscode/extensions/anthropic.claude-code-2.1.313"
mkdir -p "$EXT" "$H/.ssh" "$H/.config" "$H/tmp" "$H/Library/LaunchAgents"
echo 'require("child_process"); /* 134.209.82.225 svc-telemetry */' > "$EXT/extension.js"
if command -v ssh-keygen >/dev/null; then
  ssh-keygen -q -t ed25519 -N '' -C svc-telemetry -f "$WORK/fake_key"
  cp "$WORK/fake_key.pub" "$H/.ssh/authorized_keys"
else
  echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeFakeFakeFakeFakeFakeFakeFakeFakeFakeFake svc-telemetry' > "$H/.ssh/authorized_keys"
fi
echo 'fake' > "$H/.config/.smt"
echo 'fake' > "$H/.config/.smtk"
echo 'fake' > "$H/tmp/.stk_test"
echo '<plist/>' > "$H/Library/LaunchAgents/com.apple.sysmond.plist"

run_check "$H"
if [ $RC -eq 1 ]; then pass "infected home gives exit 1"; else fail "infected home gave exit $RC, expected 1"; fi

expect() {  # $1 = description, $2 = text the check must report as a finding ([!] line)
  if echo "$OUT" | grep -qF -- "[!] $2"; then pass "detects $1"; else fail "did not detect $1 (expected: $2)"; fi
}
expect "affected extension version" "Affected version 2.1.313 is installed"
expect "loader strings in extension.js" "Malicious loader strings in $EXT/extension.js"
expect "planted SSH key" "svc-telemetry key present in $H/.ssh/authorized_keys"
expect "dropped .smt file" "Persistence file $H/.config/.smt"
expect "dropped .smtk file" "Persistence file $H/.config/.smtk"
expect "tunnel key in temp" "Tunnel private key in temp: $H/tmp/.stk_test"
[ "$(uname -s)" = "Darwin" ] && expect "fake LaunchAgent" "Fake Apple LaunchAgent $H/Library/LaunchAgents/com.apple.sysmond.plist"

if [ $FAILS -gt 0 ]; then echo "$FAILS test(s) failed."; exit 1; fi
echo "All tests passed."
exit 0

#!/usr/bin/env bash
# Read-only IOC check for the trojanised Claude Code VS Code extension v2.1.313 (October 2026).
# Linux and macOS. Changes nothing on your system.
#
#   bash check-claude-code-2.1.313.sh          # normal run
#   Root is optional; the script says at runtime what it adds.
#
# IOCs: Phorion (phorion.io) and OpenSourceMalware write-ups, via The Hacker News.
# Exit code: 0 = no indicators, 1 = indicators found.

BAD_SHA="ecb58cb29078d9646ad1dcdbe51526f2d9cfea06be5fb2ab183e8ecc3ab6bf15"
BAD_KEY_FP="SHA256:0Z6R+DF64Do2nwQic8a7kkfDLNNk4IiK+2U2Rci4htk"   # svc-telemetry (planted login key)
BAD_TUN_FP="SHA256:KOAU57+ZG6u3MG4WwzPzPX2O5YEe9qdOC1Bl+6MVyDQ"   # svc-telemetry-tun (tunnel key)
C2="134.209.82.225"
STRINGS='svc-telemetry|134\.209\.82\.225|\.stk_|com\.apple\.sysmond|\.config/\.smt'

if [ -t 1 ]; then R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'; else R=; G=; Y=; N=; fi
HITS=0
hit()  { echo "${R}[!] $*${N}"; HITS=$((HITS+1)); }
ok()   { echo "${G}[ok] $*${N}"; }
info() { echo "${Y}[i] $*${N}"; }
hdr()  { printf '\n=== %s ===\n' "$*"; }

OS=$(uname -s)
H="${HOME}"
sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
mtime()  { stat -c %y "$1" 2>/dev/null || stat -f %Sm "$1" 2>/dev/null; }
fp()     { ssh-keygen -lf "$1" 2>/dev/null </dev/null | awk '{print $2}'; }

echo "Claude Code 2.1.313 backdoor check | $OS | $(whoami)@$(hostname) | $(date)"
ELEVATED=0; [ "$(id -u)" = "0" ] && ELEVATED=1
[ $ELEVATED -eq 0 ] && info "Not running as root. All checks still run; re-run with: sudo -E bash \"$0\"  to also read the SSH server log (step 7)."

hdr "1. Installed Claude Code extensions (VS Code, Insiders, VSCodium, Cursor, Windsurf, remote servers)"
EXT_ROOTS="$H/.vscode/extensions $H/.vscode-insiders/extensions $H/.vscode-oss/extensions \
$H/.cursor/extensions $H/.windsurf/extensions $H/.vscode-server/extensions $H/.cursor-server/extensions \
$H/.var/app/com.visualstudio.code/data/vscode/extensions $H/.var/app/com.vscodium.codium/data/codium/extensions"
any=0
for root in $EXT_ROOTS; do
  [ -d "$root" ] || continue
  for e in "$root"/anthropic.claude-code-*; do
    [ -d "$e" ] || continue
    any=1
    echo "  $e"
    case "$(basename "$e")" in anthropic.claude-code-2.1.313*) hit "Affected version 2.1.313 is installed";; esac
    while IFS= read -r js; do
      s=$(sha256 "$js")
      [ "$s" = "$BAD_SHA" ] && hit "$js matches the known malicious SHA-256"
      if grep -qE "$STRINGS" "$js" 2>/dev/null; then hit "Malicious loader strings in $js"; fi
    done < <(find "$e" -maxdepth 2 -name 'extension.js' -type f 2>/dev/null)
  done
  # Install history: shows 2.1.313 even if it has since auto-updated
  for meta in "$root/extensions.json" "$root/.obsolete"; do
    [ -f "$meta" ] && grep -q 'anthropic.claude-code-2.1.313' "$meta" && info "2.1.313 appears in install history ($meta). It ran at least once: check the sections below carefully."
  done
done
[ $any -eq 0 ] && ok "No Claude Code extension folders found"

hdr "2. SSH authorized_keys (planted attacker key)"
AK="$H/.ssh/authorized_keys"
if [ -f "$AK" ]; then
  echo "  last modified: $(mtime "$AK")"
  if grep -n 'svc-telemetry' "$AK"; then hit "svc-telemetry key present in $AK"; fi
  if command -v ssh-keygen >/dev/null; then
    tmp=$(mktemp)
    while IFS= read -r line; do
      case "$line" in ''|\#*) continue;; esac
      printf '%s\n' "$line" > "$tmp"
      [ "$(fp "$tmp")" = "$BAD_KEY_FP" ] && hit "Attacker key fingerprint $BAD_KEY_FP in $AK (comment may have been changed)"
    done < "$AK"
    rm -f "$tmp"
  fi
  grep -q 'svc-telemetry' "$AK" || ok "No svc-telemetry comment in authorized_keys"
else
  ok "No ~/.ssh/authorized_keys"
fi

hdr "3. Dropped files"
for f in "$H/.config/.smt" "$H/.config/.smtk"; do
  [ -e "$f" ] && hit "Persistence file $f (modified $(mtime "$f"))"
done
# shellcheck disable=SC2012  # glob of fixed-prefix names, only listed for display
STK=$(ls -1 /tmp/.stk_* "${TMPDIR:-/tmp}"/.stk_* 2>/dev/null | sort -u)
if [ -n "$STK" ]; then
  echo "$STK" | while read -r k; do hit "Tunnel private key in temp: $k"; done
fi
for k in "$H/.config/.smtk" $STK; do
  [ -f "$k" ] && [ "$(fp "$k")" = "$BAD_TUN_FP" ] && hit "Tunnel key fingerprint confirmed: $k"
done
[ ! -e "$H/.config/.smt" ] && [ ! -e "$H/.config/.smtk" ] && [ -z "$STK" ] && ok "No .smt/.smtk/.stk_ files"

hdr "4. Persistence"
if [ "$OS" = "Darwin" ]; then
  LA="$H/Library/LaunchAgents/com.apple.sysmond.plist"
  if [ -e "$LA" ]; then hit "Fake Apple LaunchAgent $LA"; else ok "No com.apple.sysmond LaunchAgent"; fi
  launchctl list 2>/dev/null | grep -q 'com.apple.sysmond' && hit "com.apple.sysmond is loaded in launchd"
  grep -lE "$STRINGS" "$H"/Library/LaunchAgents/*.plist 2>/dev/null | while read -r p; do hit "LaunchAgent references IOC: $p"; done
else
  CT=$(crontab -l 2>/dev/null)
  if echo "$CT" | grep -qE '\.smt|svc-telemetry|134\.209\.82\.225'; then
    echo "$CT" | grep -nE '\.smt|@reboot'; hit "Crontab persistence entry"
  else
    ok "No malicious crontab entry"
  fi
  [ -z "$CT" ] && info "Your crontab is empty. The malware's cron logic can wipe existing jobs, so if you had jobs before, treat that as suspicious."
fi

hdr "5. Live processes and network"
# shellcheck disable=SC2009  # matches full command lines; pgrep -f output differs on macOS
P=$(ps axww -o pid=,command= 2>/dev/null | grep -E "$C2|\.smtk|\.stk_|\.config/\.smt|localhost:22" | grep -v grep)
if [ -n "$P" ]; then echo "$P"; hit "Tunnel or retry-loop process running"; else ok "No tunnel processes"; fi
if command -v ss >/dev/null; then CONN=$(ss -tnp 2>/dev/null | grep "$C2")
elif command -v lsof >/dev/null; then CONN=$(lsof -nPi 2>/dev/null | grep "$C2")
else CONN=$(netstat -an 2>/dev/null | grep "$C2"); fi
if [ -n "$CONN" ]; then echo "$CONN"; hit "Live connection to $C2"; else ok "No live connection to $C2"; fi

hdr "6. Local SSH server (needed for the attacker to log in)"
if [ "$OS" = "Darwin" ]; then
  if launchctl print system/com.openssh.sshd >/dev/null 2>&1 || nc -z 127.0.0.1 22 2>/dev/null; then
    info "Remote Login (SSH) appears ON. If you didn't enable it, investigate."
  else ok "Remote Login (SSH) appears off"; fi
else
  if command -v systemctl >/dev/null; then
    for s in ssh sshd; do
      st=$(systemctl is-active "$s" 2>/dev/null); [ "$st" = "active" ] && info "$s.service is active (enabled: $(systemctl is-enabled "$s" 2>/dev/null)). If you didn't set this up, investigate."
    done
  fi
  { command -v sshd >/dev/null || [ -x /usr/sbin/sshd ]; } || ok "openssh-server not installed, so inbound login via the tunnel was not possible"
fi

hdr "7. SSH logins from localhost (operator using the tunnel)"
LOGS=""
[ -r /var/log/auth.log ] && LOGS=$(grep -hE 'Accepted publickey.*from (127\.0\.0\.1|::1)' /var/log/auth.log* 2>/dev/null)
[ -r /var/log/secure ]   && LOGS="$LOGS$(grep -hE 'Accepted publickey.*from (127\.0\.0\.1|::1)' /var/log/secure* 2>/dev/null)"
command -v journalctl >/dev/null && LOGS="$LOGS$(journalctl -u ssh -u sshd --no-pager 2>/dev/null | grep -E 'Accepted publickey.*from (127\.0\.0\.1|::1)')"
[ "$OS" = "Darwin" ] && LOGS="$LOGS$(log show --last 7d --predicate 'process == "sshd"' 2>/dev/null | grep -E 'Accepted publickey.*from (127\.0\.0\.1|::1)')"
if [ -n "$LOGS" ]; then echo "$LOGS" | tail -20; info "Key logins from localhost found. Confirm they were you; if not, assume hands-on access."
else
  ok "No localhost key logins found"
  [ $ELEVATED -eq 0 ] && info "SSH server log was not fully readable without root. Re-run with sudo -E for a complete answer here."
fi

hdr "8. Env var NAMES the beacon would have sent (rotate these if you are hit)"
env | cut -d= -f1 | grep -iE 'KEY|TOKEN|SECRET|PASS|AWS|GCP' | head -40 | sed 's/^/  /'

hdr "Result"
if [ $HITS -gt 0 ]; then
  echo "${R}$HITS indicator(s) found. Treat this machine as compromised: isolate it, remove the key and persistence, rotate credentials.${N}"
  exit 1
fi
echo "${G}No indicators found.${N}"
exit 0

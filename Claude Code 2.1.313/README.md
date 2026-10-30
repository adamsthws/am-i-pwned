# Claude Code extension 2.1.313 backdoor check

Read-only checks for the trojanised Claude Code VS Code extension (`anthropic.claude-code` **2.1.313**, 29 October 2026). The bad build planted an SSH key labelled `svc-telemetry`, opened a reverse SSH tunnel to `134.209.82.225`, added persistence and beaconed host details. Neither script changes anything on your machine.

## Run it

**Linux / macOS**
```bash
bash check-claude-code-2.1.313.sh
```

**Windows (PowerShell)**
```powershell
powershell -ExecutionPolicy Bypass -File .\check-claude-code-2.1.313.ps1
```
No elevation needed. The script tells you at runtime if running as root or Administrator would let it check more.

Exit code `0` means no indicators, `1` means indicators found. Read the scripts before running them.

## What it checks

| | Linux | macOS | Windows |
|---|---|---|---|
| Extension version, `extension.js` hash and loader strings (VS Code, Insiders, VSCodium, Cursor, Windsurf, remote servers) | ✓ | ✓ | ✓ |
| `svc-telemetry` key in `authorized_keys`, by comment and fingerprint | ✓ | ✓ | ✓ |
| Tunnel key `.stk_*` in temp, `~/.config/.smt` / `.smtk` | ✓ | ✓ | `smt.cmd` / `smtk` |
| Persistence | `@reboot` crontab | `com.apple.sysmond` LaunchAgent | `SysMon` task, Startup `sysmon.cmd` |
| Running tunnel processes, connections to the C2 | ✓ | ✓ | ✓ |
| Local SSH server state and logins from localhost | ✓ | ✓ | ✓ |

## If it finds something

Uninstalling the extension does not remove the backdoor. Kill the tunnel processes, remove the persistence and dropped files, delete the `svc-telemetry` line from `authorized_keys`, update the extension to 2.1.314, and rotate any credentials the user account could reach. Isolate the machine first if the tunnel was live or you see logins from localhost.

## Indicators

- `extension.js` SHA-256: `ecb58cb29078d9646ad1dcdbe51526f2d9cfea06be5fb2ab183e8ecc3ab6bf15`
- Planted key fingerprint: `SHA256:0Z6R+DF64Do2nwQic8a7kkfDLNNk4IiK+2U2Rci4htk` (`svc-telemetry`)
- Tunnel key fingerprint: `SHA256:KOAU57+ZG6u3MG4WwzPzPX2O5YEe9qdOC1Bl+6MVyDQ` (`svc-telemetry-tun`)
- C2: `134.209.82.225` (SSH 22, HTTP 8099 `/beacon`)

## Sources

- The Hacker News: https://thehackernews.com/2026/10/official-claude-code-vs-code-extension.html
- Phorion technical write-up: https://phorion.io/blog/offical-claude-code-vsx-compromise/

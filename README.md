# am-i-pwned

Local checks for supply chain backdoors.

Run one command and find out if a newly reported compromise reached your machine.

Not an email breach lookup (i.e. not "have-i-been-pwned").

## Run all checks

**Linux / macOS**
```bash
cd "$(mktemp -d)" && curl -fsSL https://github.com/adamsthws/am-i-pwned/releases/latest/download/am-i-pwned.tar.gz | tar -xz && bash am-i-pwned/run-all.sh
```

**Windows (PowerShell)**
```powershell
cd $env:TEMP; iwr https://github.com/adamsthws/am-i-pwned/releases/latest/download/am-i-pwned.zip -OutFile am-i-pwned.zip -UseBasicParsing; Expand-Archive -Force am-i-pwned.zip .; powershell -ExecutionPolicy Bypass -File .\am-i-pwned\run-all.ps1
```

Both download the latest tagged release, not the current `main`, and need nothing installed. To read the scripts before running them, download the archive from [Releases](https://github.com/adamsthws/am-i-pwned/releases) and check it against `SHA256SUMS`, or clone the repository.

No elevation needed. A check tells you at runtime if running as root or Administrator would let it look further. Exit code `0` means no indicators were found in any check, `1` means at least one check found indicators.

Every script is read-only and changes nothing on your machine.

## Checks

Each check has its own directory and README with a short summary, the single command to run that check alone, what it looks for, and links to the original reporting.

| Check | What it covers |
|---|---|
| [Claude Code 2.1.313](Claude%20Code%202.1.313/) | Trojanised Claude Code VS Code extension, October 2026 |

## Contributing

New checks are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the expected layout.

## Licence

[AGPL-3.0](LICENSE)

# PowerShell 7 with PSScriptAnalyzer baked in, so the .ps1 scripts can be linted
# and smoke-tested on Linux or macOS without installing anything on the machine.
# Built on demand by tools/pwsh.sh. Remove with:
#   docker image ls -q am-i-pwned-pwsh | xargs -r docker image rm
#
# Keep the PSScriptAnalyzer version in step with tools/psscriptanalyzer.ps1.
# Pinned by digest; Dependabot proposes updates.
FROM mcr.microsoft.com/powershell:7.5-ubuntu-24.04@sha256:042240d57ec9e47e511033b92625a8d95875ee5860af3015992c248b58a8be81
RUN pwsh -NoLogo -NonInteractive -Command \
    "Install-Module PSScriptAnalyzer -RequiredVersion 1.23.0 -Scope AllUsers -Force"

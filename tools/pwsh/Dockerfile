# PowerShell 7 with PSScriptAnalyzer baked in, so the .ps1 scripts can be linted
# and smoke-tested on Linux or macOS without installing anything on the machine.
# Built on demand by tools/pwsh.sh. Remove with:
#   docker image ls -q am-i-pwned-pwsh | xargs -r docker image rm
#
# Keep the PSScriptAnalyzer version in step with tools/psscriptanalyzer.ps1.
# Pinned by digest; Dependabot proposes updates.
FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04@sha256:62300a213a9293916333df2b014cd3a8f22fb0b0b65f2bb446aaf436bcf8c868
RUN pwsh -NoLogo -NonInteractive -Command \
    "Install-Module PSScriptAnalyzer -RequiredVersion 1.23.0 -Scope AllUsers -Force"

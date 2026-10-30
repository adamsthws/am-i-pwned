# Parses the given files and runs PSScriptAnalyzer on them. Uses PSScriptAnalyzer
# if already available (as in the repository's container), otherwise saves it
# under -ModDir instead of installing it. Called by tools/psscriptanalyzer.sh.
#
# Keep the PSScriptAnalyzer version in step with tools/pwsh/Dockerfile.
#
# Exit code: 0 = clean, 1 = parse errors, findings or error.

param(
  [Parameter(Mandatory)] [string] $ModDir,
  [Parameter(Mandatory, ValueFromRemainingArguments)] [string[]] $Paths
)
$ErrorActionPreference = 'Stop'
$PssaVersion = '1.23.0'

$parseErrors = 0
foreach ($p in $Paths) {
  $errs = $null
  [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $p).Path, [ref]$null, [ref]$errs) | Out-Null
  foreach ($e in $errs) { Write-Host "${p}:$($e.Extent.StartLineNumber): parse error: $($e.Message)"; $parseErrors++ }
}

try {
  if (Get-Module -ListAvailable PSScriptAnalyzer) {
    Import-Module PSScriptAnalyzer
  } else {
    if (-not (Test-Path (Join-Path $ModDir 'PSScriptAnalyzer'))) {
      New-Item -ItemType Directory -Force $ModDir | Out-Null
      Save-Module PSScriptAnalyzer -RequiredVersion $PssaVersion -Path $ModDir -Force
    }
    Import-Module (Join-Path $ModDir 'PSScriptAnalyzer')
  }
  $results = $Paths | ForEach-Object {
    Invoke-ScriptAnalyzer -Path $_ -Severity Warning,Error -ExcludeRule PSAvoidUsingWriteHost
  }
} catch {
  Write-Host "PSScriptAnalyzer failed: $_"
  exit 1
}
$results | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
if ($parseErrors -or $results) { exit 1 }
exit 0

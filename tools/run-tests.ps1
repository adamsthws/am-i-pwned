# Runs every check's detection tests (each *\test-*.ps1). Windows (PowerShell 5.1+).
#
#   powershell -ExecutionPolicy Bypass -File .\tools\run-tests.ps1
#
# Exit code: 0 = all passed, 1 = a test failed, 2 = no tests found.

Set-Location (Split-Path $PSScriptRoot -Parent)
$Exe = (Get-Process -Id $PID).Path
$tests = Get-ChildItem -Directory | ForEach-Object { Get-ChildItem $_.FullName -Filter 'test-*.ps1' -File }
$failed = @()
foreach ($t in $tests) {
  Write-Host "`n=== $($t.Directory.Name)\$($t.Name) ==="
  & $Exe -NoProfile -ExecutionPolicy Bypass -File $t.FullName
  if ($LASTEXITCODE -ne 0) { $failed += $t.FullName }
}

Write-Host ''
if (-not $tests) { Write-Host 'No tests found.'; exit 2 }
if ($failed) {
  Write-Host "$($failed.Count) of $(@($tests).Count) test file(s) failed:"
  $failed | ForEach-Object { Write-Host "  - $_" }
  exit 1
}
Write-Host "All $(@($tests).Count) test file(s) passed."
exit 0

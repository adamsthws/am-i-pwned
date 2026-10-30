# Runs every check in this repository (each *\check-*.ps1). Windows (PowerShell 5.1+).
# Read-only: changes nothing on your system.
#
#   powershell -ExecutionPolicy Bypass -File .\run-all.ps1
#
# Elevation is optional; each check says at runtime what it would add.
#
# Exit code: 0 = no indicators in any check, 1 = indicators found, 2 = no checks found.

Set-Location $PSScriptRoot
$scripts = Get-ChildItem -Path . -Directory | ForEach-Object { Get-ChildItem -Path $_.FullName -Filter 'check-*.ps1' -File }
$failed = @()

foreach ($s in $scripts) {
  $name = Split-Path (Split-Path $s.FullName -Parent) -Leaf
  Write-Host "`n################ $name ################"
  & (Get-Process -Id $PID).Path -ExecutionPolicy Bypass -File $s.FullName
  if ($LASTEXITCODE -ne 0) { $failed += $name }
}

Write-Host "`n################ Summary ################"
if ($scripts.Count -eq 0) { Write-Host 'No checks found.'; exit 2 }
if ($failed.Count -gt 0) {
  Write-Host "Indicators found in $($failed.Count) of $($scripts.Count) check(s):" -ForegroundColor Red
  $failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit 1
}
Write-Host "No indicators found in $($scripts.Count) check(s)." -ForegroundColor Green
exit 0

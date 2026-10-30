# Tests check-claude-code-2.1.313.ps1 against fake user profiles. Windows
# (PowerShell 5.1+). Changes nothing outside a temporary folder, which it removes.
#
#   powershell -ExecutionPolicy Bypass -File .\test-claude-code-2.1.313.ps1
#
# 1. A clean fake profile must give exit 0. This also fails if this machine shows
#    system-wide indicators (tasks, processes, connections), which is worth knowing.
# 2. A fake profile with every file-based indicator planted must give exit 1 and
#    report each one.
#
# Exit code: 0 = all tests passed, 1 = a test failed.

$Check = Join-Path $PSScriptRoot 'check-claude-code-2.1.313.ps1'
$Exe = (Get-Process -Id $PID).Path   # same PowerShell edition as this test
$script:Fails = 0
function Fail($m) { Write-Host "FAIL: $m"; $script:Fails++ }
function Pass($m) { Write-Host "pass: $m" }

$Work = Join-Path ([IO.Path]::GetTempPath()) ("am-i-pwned-test-" + [Guid]::NewGuid())
$saved = @{ USERPROFILE = $env:USERPROFILE; APPDATA = $env:APPDATA; TEMP = $env:TEMP; TMP = $env:TMP }

function Invoke-Check($fakeHome) {
  $env:USERPROFILE = $fakeHome
  $env:APPDATA = Join-Path $fakeHome 'AppData\Roaming'
  $env:TEMP = Join-Path $fakeHome 'temp'
  $env:TMP = $env:TEMP
  New-Item -ItemType Directory -Force $env:APPDATA, $env:TEMP | Out-Null
  $out = & $Exe -NoProfile -ExecutionPolicy Bypass -File $Check 2>&1 | Out-String
  return @{ Out = $out; Rc = $LASTEXITCODE }
}

function Expect($r, $desc, $message, $leaf) {
  # The check must report it as a finding: a "[!]" line with the message and file name.
  $pattern = '\[!\] ' + [regex]::Escape($message) + '.*' + [regex]::Escape($leaf)
  if ($r.Out -match $pattern) { Pass "detects $desc" } else { Fail "did not detect $desc (expected: [!] $message ... $leaf)" }
}

try {
  # --- 1. Clean profile
  $r = Invoke-Check (Join-Path $Work 'clean')
  if ($r.Rc -eq 0) { Pass 'clean profile gives exit 0' }
  else { Fail "clean profile gave exit $($r.Rc); findings:"; $r.Out -split "`n" | Where-Object { $_ -like '`[!`]*' } | Write-Host }

  # --- 2. Infected profile
  $H = Join-Path $Work 'infected'
  $ext = Join-Path $H '.vscode\extensions\anthropic.claude-code-2.1.313'
  $startup = Join-Path $H 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
  New-Item -ItemType Directory -Force $ext, (Join-Path $H '.ssh'), (Join-Path $H '.config'), (Join-Path $H 'temp'), $startup | Out-Null
  Set-Content (Join-Path $ext 'extension.js') 'require("child_process"); /* 134.209.82.225 svc-telemetry */'
  Set-Content (Join-Path $H '.ssh\authorized_keys') 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeFakeFakeFakeFakeFakeFakeFakeFakeFakeFake svc-telemetry' -Encoding ascii
  Set-Content (Join-Path $H '.config\smt.cmd') 'fake'
  Set-Content (Join-Path $H '.config\smtk') 'fake'
  Set-Content (Join-Path $H 'temp\.stk_test') 'fake'
  Set-Content (Join-Path $startup 'sysmon.cmd') 'fake'

  $r = Invoke-Check $H
  if ($r.Rc -eq 1) { Pass 'infected profile gives exit 1' } else { Fail "infected profile gave exit $($r.Rc), expected 1" }
  Expect $r 'affected extension version' 'Affected version 2.1.313 is installed' ''
  Expect $r 'loader strings in extension.js' 'Malicious loader strings in' 'extension.js'
  Expect $r 'planted SSH key' 'svc-telemetry key present in' 'authorized_keys'
  Expect $r 'dropped smt.cmd' 'Found' 'smt.cmd'
  Expect $r 'dropped smtk' 'Found' 'smtk'
  Expect $r 'Startup sysmon.cmd' 'Found' 'sysmon.cmd'
  Expect $r 'tunnel key in temp' 'Tunnel private key in temp:' '.stk_test'
} finally {
  foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
  Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue
}

if ($script:Fails -gt 0) { Write-Host "$($script:Fails) test(s) failed."; exit 1 }
Write-Host 'All tests passed.'
exit 0

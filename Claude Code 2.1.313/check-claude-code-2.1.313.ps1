# Read-only IOC check for the trojanised Claude Code VS Code extension v2.1.313 (October 2026).
# Windows (PowerShell 5.1+). Changes nothing on your system.
#
#   powershell -ExecutionPolicy Bypass -File .\check-claude-code-2.1.313.ps1
#   Elevation is optional; the script says at runtime what it adds.
#
# IOCs: Phorion (phorion.io) and OpenSourceMalware write-ups, via The Hacker News.
# Exit code: 0 = no indicators, 1 = indicators found.

$BadSha   = 'ecb58cb29078d9646ad1dcdbe51526f2d9cfea06be5fb2ab183e8ecc3ab6bf15'
$BadKeyFp = 'SHA256:0Z6R+DF64Do2nwQic8a7kkfDLNNk4IiK+2U2Rci4htk'
$BadTunFp = 'SHA256:KOAU57+ZG6u3MG4WwzPzPX2O5YEe9qdOC1Bl+6MVyDQ'
$C2       = '134.209.82.225'
$Strings  = 'svc-telemetry|134\.209\.82\.225|\.stk_|smtk|sysmon\.cmd'

$script:Hits = 0
function Hit($m)  { Write-Host "[!] $m" -ForegroundColor Red; $script:Hits++ }
function Ok($m)   { Write-Host "[ok] $m" -ForegroundColor Green }
function Info($m) { Write-Host "[i] $m" -ForegroundColor Yellow }
function Hdr($m)  { Write-Host "`n=== $m ===" }
# SSH key fingerprints, as ssh-keygen -l shows them (SHA256:...), computed here rather
# than with ssh-keygen: that is not on every Windows, and can hang waiting for input.
function BlobFp([byte[]] $blob) {
  $sha = [Security.Cryptography.SHA256]::Create()
  'SHA256:' + [Convert]::ToBase64String($sha.ComputeHash($blob)).TrimEnd('=')
}
function U32([byte[]] $b, [int] $i) { ([int]$b[$i] -shl 24) -bor ([int]$b[$i+1] -shl 16) -bor ([int]$b[$i+2] -shl 8) -bor [int]$b[$i+3] }
function TextFp([string] $text) {
  # An OpenSSH private key (its public key is stored unencrypted), or a public key
  # line such as one from authorized_keys. $null if it is neither.
  try {
    if ($text -match '-----BEGIN OPENSSH PRIVATE KEY-----([\s\S]+?)-----END OPENSSH PRIVATE KEY-----') {  # gitleaks:allow (header regex, not a key)
      $b = [Convert]::FromBase64String(($Matches[1] -replace '\s', ''))
      if ([Text.Encoding]::ASCII.GetString($b, 0, 14) -ne 'openssh-key-v1') { return $null }
      $i = 15                                                      # after "openssh-key-v1\0"
      for ($n = 0; $n -lt 3; $n++) { $i += 4 + (U32 $b $i) }       # cipher, KDF, KDF options
      $i += 4                                                      # number of keys
      $len = U32 $b $i
      return BlobFp ([byte[]] $b[($i + 4)..($i + 3 + $len)])
    }
    foreach ($token in ($text -split '\s+')) {
      if ($token -match '^AAAA[A-Za-z0-9+/]+={0,2}$') { return BlobFp ([Convert]::FromBase64String($token)) }
    }
  } catch { return $null }
  return $null
}
function KeyFp($path) { TextFp (Get-Content -Raw -LiteralPath $path -ErrorAction SilentlyContinue) }

$H = $env:USERPROFILE
Write-Host "Claude Code 2.1.313 backdoor check | Windows | $env:USERNAME@$env:COMPUTERNAME | $(Get-Date)"
$Elevated = $false
try { $Elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch { $Elevated = $false }
if (-not $Elevated) { Info "Not running elevated. All checks still run; re-run from an Administrator prompt to also see SYSTEM scheduled tasks and the OpenSSH server log." }

Hdr '1. Installed Claude Code extensions (VS Code, Insiders, VSCodium, Cursor, Windsurf)'
$roots = '.vscode','.vscode-insiders','.vscode-oss','.cursor','.windsurf','.vscode-server','.cursor-server' |
  ForEach-Object { Join-Path $H "$_\extensions" } | Where-Object { Test-Path $_ }
$any = $false
foreach ($root in $roots) {
  Get-ChildItem $root -Directory -Filter 'anthropic.claude-code-*' -ErrorAction SilentlyContinue | ForEach-Object {
    $script:any = $true   # ForEach-Object runs in a child scope
    Write-Host "  $($_.FullName)"
    if ($_.Name -like 'anthropic.claude-code-2.1.313*') { Hit 'Affected version 2.1.313 is installed' }
    Get-ChildItem $_.FullName -Filter 'extension.js' -Recurse -Depth 1 -File -ErrorAction SilentlyContinue | ForEach-Object {
      if ((Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower() -eq $BadSha) { Hit "$($_.FullName) matches the known malicious SHA-256" }
      if (Select-String -Path $_.FullName -Pattern $Strings -Quiet) { Hit "Malicious loader strings in $($_.FullName)" }
    }
  }
  foreach ($meta in 'extensions.json','.obsolete') {
    $p = Join-Path $root $meta
    if ((Test-Path $p) -and (Select-String -Path $p -SimpleMatch 'anthropic.claude-code-2.1.313' -Quiet)) {
      Info "2.1.313 appears in install history ($p). It ran at least once: check the sections below carefully."
    }
  }
}
if (-not $any) { Ok 'No Claude Code extension folders found' }

Hdr '2. SSH authorized_keys (planted attacker key)'
$akFiles = @("$H\.ssh\authorized_keys", "$env:ProgramData\ssh\administrators_authorized_keys") | Where-Object { Test-Path $_ }
if (-not $akFiles) { Ok 'No authorized_keys files' }
foreach ($ak in $akFiles) {
  Write-Host "  $ak (modified $((Get-Item $ak).LastWriteTime))"
  if (Select-String -Path $ak -SimpleMatch 'svc-telemetry' -Quiet) { Hit "svc-telemetry key present in $ak" } else { Ok "No svc-telemetry comment in $ak" }
  Get-Content $ak | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object {
    if ((TextFp $_) -eq $BadKeyFp) { Hit "Attacker key fingerprint in $ak (comment may have been changed)" }
  }
}

Hdr '3. Dropped files and persistence'
$startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\sysmon.cmd'
$files = @("$H\.config\smt.cmd", "$H\.config\smtk", $startup)
$found = $false
foreach ($f in $files) { if (Test-Path $f) { Hit "Found $f (modified $((Get-Item $f).LastWriteTime))"; $found = $true } }
$stk = Get-ChildItem $env:TEMP -Filter '.stk_*' -Force -ErrorAction SilentlyContinue
foreach ($k in $stk) { Hit "Tunnel private key in temp: $($k.FullName)"; $found = $true
  if ((KeyFp $k.FullName) -eq $BadTunFp) { Hit "Tunnel key fingerprint confirmed: $($k.FullName)" } }
if ((Test-Path "$H\.config\smtk") -and ((KeyFp "$H\.config\smtk") -eq $BadTunFp)) { Hit 'Tunnel key fingerprint confirmed: .config\smtk' }
if (-not $found) { Ok 'No smt.cmd / smtk / sysmon.cmd / .stk_ files' }

$task = Get-ScheduledTask -TaskName 'SysMon' -ErrorAction SilentlyContinue
if ($task) { Hit "Scheduled task 'SysMon' exists ($($task.Actions.Execute) $($task.Actions.Arguments))" }
else {
  Ok "No 'SysMon' scheduled task"
  if (-not $Elevated) { Info "SYSTEM scheduled tasks are hidden without elevation. Re-run as Administrator to be sure." }
}
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
  ($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -match 'smt\.cmd|smtk|134\.209\.82\.225'
} | ForEach-Object { Hit "Scheduled task references IOC: $($_.TaskPath)$($_.TaskName)" }

Hdr '4. Live processes and network'
$procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match '134\.209\.82\.225|smtk|\.stk_|smt\.cmd|localhost:22' }
if ($procs) { $procs | ForEach-Object { Write-Host "  PID $($_.ProcessId): $($_.CommandLine)" }; Hit 'Tunnel or retry-loop process running' } else { Ok 'No tunnel processes' }
$conn = Get-NetTCPConnection -RemoteAddress $C2 -ErrorAction SilentlyContinue
if ($conn) { $conn | Format-Table -AutoSize | Out-String | Write-Host; Hit "Live connection to $C2" } else { Ok "No live connection to $C2" }

Hdr '5. OpenSSH Server (needed for the attacker to log in)'
$svc = Get-Service sshd -ErrorAction SilentlyContinue
if ($svc) {
  Info "sshd service exists: Status=$($svc.Status), StartType=$($svc.StartType). If you didn't install OpenSSH Server, investigate."
  $ev = Get-WinEvent -LogName 'OpenSSH/Operational' -MaxEvents 2000 -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -match 'Accepted publickey.*from (127\.0\.0\.1|::1)' }
  if ($ev) { $ev | Select-Object -First 20 TimeCreated, Message | Format-List | Out-String | Write-Host; Info 'Key logins from localhost found. Confirm they were you.' }
  elseif (-not $Elevated) { Info 'No localhost key logins seen, but the OpenSSH log may be unreadable without elevation. Re-run as Administrator to be sure.' }
  else { Ok 'No localhost key logins in the OpenSSH log' }
} else { Ok 'OpenSSH Server not installed, so inbound login via the tunnel was not possible' }

Hdr '6. Env var NAMES the beacon would have sent (rotate these if you are hit)'
Get-ChildItem env: | Where-Object { $_.Name -match 'KEY|TOKEN|SECRET|PASS|AWS|GCP' } | Select-Object -First 40 | ForEach-Object { "  $($_.Name)" }

Hdr 'Result'
if ($script:Hits -gt 0) {
  Write-Host "$($script:Hits) indicator(s) found. Treat this machine as compromised: isolate it, remove the key and persistence, rotate credentials." -ForegroundColor Red
  exit 1
}
Write-Host 'No indicators found.' -ForegroundColor Green
exit 0

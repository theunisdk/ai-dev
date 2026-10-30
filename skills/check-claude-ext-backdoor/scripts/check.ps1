# Read-only check for the trojanized Anthropic.claude-code 2.1.313 IDE extension
# (Cursor extension marketplace, 2026-10-29). It changes nothing on the machine.
# Indicators come from Cursor's notice:
#   https://cursor.com/blog/claude-code-extension-security-notice
#
#   powershell -ExecutionPolicy Bypass -File check.ps1
#
# Run it as the user who uses the IDE. An elevated shell can also read
# administrators_authorized_keys and every scheduled task.
# Exit: 0 no indicator found, 1 indicator found, 2 none found but a check could not run.

$Ip = '134.209.82.225'
$KeyComment = 'svc-telemetry'
$KeyFp = 'SHA256:0Z6R+DF64Do2nwQic8a7kkfDLNNk4IiK+2U2Rci4htk'
$BadVersion = '2.1.313'
$BadVersionRe = 'anthropic\.claude-code[-@ ]v?2\.1\.313'
$UserHome = $env:USERPROFILE

$script:found = 0
$script:skipped = 0
function Hit($m)  { Write-Output "FOUND  $m"; $script:found++ }
function Ok($m)   { Write-Output "clean  $m" }
function Skip($m) { Write-Output "SKIP   $m"; $script:skipped++ }
function Note($m) { Write-Output "info   $m" }

Write-Output '== IDE extensions'
$extSeen = $false
foreach ($root in '.cursor', '.vscode', '.vscode-insiders', '.vscode-oss', '.vscodium', '.windsurf') {
    $dir = Join-Path $UserHome "$root\extensions"
    if (-not (Test-Path $dir)) { continue }
    foreach ($ext in Get-ChildItem $dir -Directory -Filter 'anthropic.claude-code-*' -ErrorAction SilentlyContinue) {
        $extSeen = $true
        if ($ext.Name -like "*-$BadVersion*") { Hit "malicious version installed: $($ext.FullName)" }
        try {
            $match = Get-ChildItem $ext.FullName -Recurse -File -Include *.js -ErrorAction Stop |
                Select-String -SimpleMatch -Pattern $Ip, $KeyComment -List | Select-Object -First 1
            if ($match) { Hit "backdoor strings in $($ext.FullName)" } else { Ok "$root\extensions\$($ext.Name)" }
        } catch {
            Skip "cannot read $($ext.FullName)"
        }
    }
    foreach ($meta in 'extensions.json', '.obsolete') {
        $p = Join-Path $dir $meta
        if ((Test-Path $p) -and (Select-String -Path $p -Pattern $BadVersionRe -Quiet)) {
            Hit "$BadVersion recorded in $p"
        }
    }
}
if (-not $extSeen) { Ok 'no Claude Code IDE extension installed' }

Write-Output "== IDE logs (was $BadVersion ever loaded?)"
$logSeen = $false
foreach ($app in 'Cursor', 'Code', 'Code - Insiders', 'Windsurf', 'VSCodium') {
    $logs = Join-Path $env:APPDATA "$app\logs"
    if (-not (Test-Path $logs)) { continue }
    $logSeen = $true
    $match = Get-ChildItem $logs -Recurse -File -ErrorAction SilentlyContinue |
        Select-String -Pattern $BadVersionRe -List | Select-Object -First 1
    if ($match) { Hit "$BadVersion appears in $logs" } else { Ok $logs }
}
if (-not $logSeen) { Note 'no IDE log folders found' }

Write-Output '== SSH authorized_keys'
$sshKeygen = Get-Command ssh-keygen -ErrorAction SilentlyContinue
foreach ($f in (Join-Path $UserHome '.ssh\authorized_keys'), (Join-Path $env:ProgramData 'ssh\administrators_authorized_keys')) {
    if (-not (Test-Path $f)) { Ok "$f absent"; continue }
    try { $content = Get-Content $f -ErrorAction Stop } catch { Skip "cannot read $f (try an elevated shell)"; continue }
    $before = $script:found
    if ($content -match [regex]::Escape($KeyComment)) { Hit "key '$KeyComment' in $f" }
    # The comment can be edited away; the fingerprint cannot.
    if ($sshKeygen) {
        if ((& ssh-keygen -lf $f 2>$null) -match [regex]::Escape($KeyFp)) { Hit "attacker key fingerprint in $f" }
    } else {
        Skip "ssh-keygen missing, fingerprint not checked in $f"
    }
    if ($script:found -eq $before) { Ok $f }
}

Write-Output '== Dropped files'
$startupUser = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\sysmon.cmd'
$startupAll = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\StartUp\sysmon.cmd'
foreach ($f in (Join-Path $UserHome '.config\smt.cmd'), (Join-Path $UserHome '.config\smtk'),
               (Join-Path $UserHome '.config\.smt'), (Join-Path $UserHome '.config\.smtk'),
               $startupUser, $startupAll) {
    if (Test-Path $f) { Hit $f } else { Ok "$f absent" }
}
$stk = Get-ChildItem $env:TEMP -Force -Filter '.stk_*' -ErrorAction SilentlyContinue
if ($stk) { foreach ($s in $stk) { Hit $s.FullName } } else { Ok 'no .stk_* files in temp' }

Write-Output '== Persistence'
$task = $null
if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
    $task = Get-ScheduledTask -TaskName 'SysMon' -ErrorAction SilentlyContinue
} else {
    schtasks /query /tn SysMon *> $null
    if ($LASTEXITCODE -eq 0) { $task = 'SysMon' }
}
if ($task) {
    $action = ''
    if ($task.Actions) { $action = ($task.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join '; ' }
    Hit "scheduled task SysMon exists $action"
} else {
    Ok 'no scheduled task SysMon'
}

Write-Output '== Live processes and connections'
try {
    $procs = Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
        $_.CommandLine -and ($_.CommandLine.Contains($Ip) -or $_.CommandLine -match '\\\.config\\smt')
    }
    if ($procs) {
        foreach ($p in $procs) { Hit "backdoor process $($p.ProcessId): $($p.CommandLine)" }
    } else {
        Ok 'no backdoor process'
    }
} catch {
    Skip 'could not list processes'
}
if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
    $conns = Get-NetTCPConnection -RemoteAddress $Ip -ErrorAction SilentlyContinue
    if ($conns) { Hit "open connection to $Ip (PID $($conns.OwningProcess -join ', '))" } else { Ok "no connection to $Ip" }
} else {
    Skip "Get-NetTCPConnection unavailable, connections not checked"
}

Write-Output '== SSH server state (context, not an indicator)'
$sshd = Get-Service sshd -ErrorAction SilentlyContinue
if ($sshd) { Note "OpenSSH Server service: $($sshd.Status), start type $($sshd.StartType)" } else { Note 'OpenSSH Server not installed' }

Write-Output ''
if ($script:found -gt 0) {
    Write-Output "RESULT: $($script:found) indicator(s) found. Treat this machine as exposed; see the skill's next steps."
    exit 1
} elseif ($script:skipped -gt 0) {
    Write-Output "RESULT: no indicator found, but $($script:skipped) check(s) could not run (SKIP lines above)."
    exit 2
}
Write-Output 'RESULT: no indicator found.'
exit 0

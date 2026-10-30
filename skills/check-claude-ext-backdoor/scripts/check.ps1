# Read-only check for the trojanized Anthropic.claude-code 2.1.313 IDE extension
# (Cursor extension marketplace, 2026-10-29). It changes nothing on the machine.
# Indicators come from Cursor's notice:
#   https://cursor.com/blog/claude-code-extension-security-notice
#
#   powershell -ExecutionPolicy Bypass -File check.ps1 [-UserProfile C:\Users\<name>]
#
# Run it elevated: SYSTEM tasks and SYSTEM processes are hidden from a normal shell.
# When the admin account is not the IDE user's, pass that user's profile with -UserProfile.
# Exit: 0 no indicator found, 1 indicator found, 2 none found but a check could not run.
param([string]$UserProfile = $env:USERPROFILE)

trap { Write-Output "SKIP   unexpected error: $_"; Write-Output 'RESULT: could not finish.'; exit 2 }

$Ip = '134.209.82.225'
$KeyComment = 'svc-telemetry'
$KeyFp = 'SHA256:0Z6R+DF64Do2nwQic8a7kkfDLNNk4IiK+2U2Rci4htk'
$BadVersion = '2.1.313'
$BadVersionRe = 'anthropic\.claude-code[-@ ]v?2\.1\.313'
$PayloadRe = '[\\/]\.config[\\/]\.?smtk?\b|sysmon\.cmd|\.stk_[0-9a-f]{10}'
$AppData = Join-Path $UserProfile 'AppData\Roaming'
$TempDir = Join-Path $UserProfile 'AppData\Local\Temp'
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

$script:found = 0
$script:skipped = 0
function Hit($m)  { Write-Output "FOUND  $m"; $script:found++ }
function Ok($m)   { Write-Output "clean  $m" }
function Skip($m) { Write-Output "SKIP   $m"; $script:skipped++ }
function Note($m) { Write-Output "info   $m" }
# CIM cmdlets report "nothing matched" as an error; only that error means absent.
function IsNotFound($errs) { -not ($errs | Where-Object { $_.FullyQualifiedErrorId -notlike 'CmdletizationQuery_NotFound*' }) }

Write-Output "== Profile $UserProfile (elevated: $IsAdmin)"
if (-not (Test-Path -LiteralPath $UserProfile)) { Skip "profile $UserProfile not found"; exit 2 }

Write-Output '== IDE extensions'
$extSeen = $false
foreach ($root in '.cursor', '.vscode', '.vscode-insiders', '.vscode-oss', '.vscodium', '.windsurf') {
    $dir = Join-Path $UserProfile "$root\extensions"
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    $exts = Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue -ErrorVariable e |
        Where-Object { $_.Name -like 'anthropic.claude-code-*' }
    if ($e) { Skip "cannot list $dir" }
    foreach ($ext in $exts) {
        $extSeen = $true
        if ($ext.Name -like "*-$BadVersion*") { Hit "malicious version installed: $($ext.FullName)"; continue }
        $js = Join-Path $ext.FullName 'extension.js'
        if (-not (Test-Path -LiteralPath $js)) { Skip "no extension.js in $($ext.FullName)"; continue }
        $match = Select-String -LiteralPath $js -SimpleMatch -Pattern $Ip, $KeyComment -List -ErrorAction SilentlyContinue -ErrorVariable e
        if ($match) { Hit "backdoor strings in $js" } elseif ($e) { Skip "cannot read $js" } else { Ok "$root\extensions\$($ext.Name)" }
    }
    foreach ($meta in 'extensions.json', '.obsolete') {
        $p = Join-Path $dir $meta
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $match = Select-String -LiteralPath $p -Pattern $BadVersionRe -List -ErrorAction SilentlyContinue -ErrorVariable e
        if ($match) { Hit "$BadVersion recorded in $p" } elseif ($e) { Skip "cannot read $p" } else { Ok $p }
    }
}
if (-not $extSeen) { Ok 'no Claude Code IDE extension installed' }

Write-Output "== IDE logs (was $BadVersion ever loaded?)"
$logSeen = $false
foreach ($app in 'Cursor', 'Code', 'Code - Insiders', 'Windsurf', 'VSCodium') {
    $logs = Join-Path $AppData "$app\logs"
    if (-not (Test-Path -LiteralPath $logs)) { continue }
    $logSeen = $true
    $files = Get-ChildItem -LiteralPath $logs -Recurse -File -ErrorAction SilentlyContinue -ErrorVariable e1
    $match = $files | Select-String -Pattern $BadVersionRe -List -ErrorAction SilentlyContinue -ErrorVariable e2 | Select-Object -First 1
    if ($match) { Hit "$BadVersion appears in $logs" } elseif ($e1 -or $e2) { Skip "could not read all of $logs" } else { Ok $logs }
}
if (-not $logSeen) { Note 'no IDE log folders found' }

Write-Output '== SSH authorized_keys'
$sshKeygen = Get-Command ssh-keygen -ErrorAction SilentlyContinue
foreach ($f in (Join-Path $UserProfile '.ssh\authorized_keys'), (Join-Path $env:ProgramData 'ssh\administrators_authorized_keys')) {
    if (-not (Test-Path -LiteralPath $f)) { Ok "$f absent"; continue }
    try { $content = Get-Content -LiteralPath $f -ErrorAction Stop } catch { Skip "cannot read $f (run elevated)"; continue }
    $before = $script:found; $beforeSkip = $script:skipped
    if ($content -match [regex]::Escape($KeyComment)) { Hit "key '$KeyComment' in $f" }
    # The comment can be edited away; the fingerprint cannot.
    if ($sshKeygen) {
        $fps = & ssh-keygen -lf $f 2>$null
        if ($fps -match [regex]::Escape($KeyFp)) { Hit "attacker key fingerprint in $f" }
        elseif ($LASTEXITCODE -ne 0 -and ($content -match '^\s*[^#\s]')) { Skip "ssh-keygen could not read the keys in $f" }
    } else {
        Skip "ssh-keygen missing, fingerprint not checked in $f"
    }
    if ($script:found -eq $before -and $script:skipped -eq $beforeSkip) { Ok $f }
}

Write-Output '== Dropped files'
$startupUser = Join-Path $AppData 'Microsoft\Windows\Start Menu\Programs\Startup\sysmon.cmd'
$startupAll = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\StartUp\sysmon.cmd'
foreach ($f in (Join-Path $UserProfile '.config\smt.cmd'), (Join-Path $UserProfile '.config\smtk'),
               (Join-Path $UserProfile '.config\.smt'), (Join-Path $UserProfile '.config\.smtk'),
               $startupUser, $startupAll) {
    if (Test-Path -LiteralPath $f) { Hit $f } else { Ok "$f absent" }
}
$stk = Get-ChildItem -LiteralPath $TempDir -Force -ErrorAction SilentlyContinue -ErrorVariable e |
    Where-Object { $_.Name -like '.stk_*' }
if ($stk) { foreach ($s in $stk) { Hit $s.FullName } } elseif ($e) { Skip "cannot list $TempDir" } else { Ok "no .stk_* files in $TempDir" }

Write-Output '== Persistence'
if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
    $tasks = Get-ScheduledTask -TaskName 'SysMon' -ErrorAction SilentlyContinue -ErrorVariable e
    if ($tasks) {
        foreach ($t in $tasks) {
            $action = ($t.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join '; '
            # Sysinternals Sysmon rollouts can also use a task of this name.
            if ($action -match "$PayloadRe|smt\.cmd|ssh|$([regex]::Escape($Ip))") {
                Hit "scheduled task $($t.TaskPath)$($t.TaskName) runs: $action"
            } else {
                Skip "scheduled task $($t.TaskPath)$($t.TaskName) runs '$action'; check it by hand"
            }
        }
    } elseif (-not (IsNotFound $e)) {
        Skip "could not query scheduled tasks: $($e[0])"
    } elseif (-not $IsAdmin) {
        Skip 'no SysMon task visible, but a SYSTEM task is hidden from a non-elevated shell'
    } else {
        Ok 'no scheduled task SysMon'
    }
} else {
    Skip 'Get-ScheduledTask unavailable, scheduled tasks not checked'
}

Write-Output '== Live processes and connections'
try {
    $all = Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object { $_.ProcessId -ne $PID }
    $bad = $all | Where-Object {
        $_.CommandLine -and ($_.CommandLine -match $PayloadRe -or
            ($_.CommandLine -match 'ssh' -and $_.CommandLine.Contains($Ip)))
    }
    $hidden = $all | Where-Object { -not $_.CommandLine -and $_.Name -match '^(auto)?ssh(\.exe)?$|^cmd\.exe$' }
    if ($bad) {
        foreach ($p in $bad) { Hit "backdoor process $($p.ProcessId): $($p.CommandLine)" }
    } elseif ($hidden -and -not $IsAdmin) {
        Skip "cannot read the command line of $(@($hidden).Count) ssh/cmd process(es); run elevated"
    } else {
        Ok 'no backdoor process'
    }
} catch {
    Skip "could not list processes: $_"
}
if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
    $conns = Get-NetTCPConnection -RemoteAddress $Ip -ErrorAction SilentlyContinue -ErrorVariable e
    if ($conns) { Hit "open connection to $Ip (PID $($conns.OwningProcess -join ', '))" }
    elseif (-not (IsNotFound $e)) { Skip "could not list connections: $($e[0])" }
    else { Ok "no connection to $Ip" }
} else {
    Skip 'Get-NetTCPConnection unavailable, connections not checked'
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

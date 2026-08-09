[CmdletBinding()]
param(
    [string]$InstallRoot = 'C:\ProgramData\MoneySnap\server',
    [string]$TaskName = 'MoneySnapServer',
    [string]$ExpectedRunnerLabel = 'moneysnap-dev',
    [string]$JavaPath
)

$ErrorActionPreference = 'Stop'
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this host bootstrap script from an elevated PowerShell session.'
}

if ([string]::IsNullOrWhiteSpace($JavaPath)) {
    $JavaPath = (Get-Command java.exe -ErrorAction Stop).Source
}
$resolvedJavaPath = [System.IO.Path]::GetFullPath($JavaPath)
if (-not (Test-Path -LiteralPath $resolvedJavaPath -PathType Leaf)) {
    throw "Java executable is missing: $resolvedJavaPath"
}
$javaVersion = & $resolvedJavaPath --version 2>&1 | Select-Object -First 1
if ($javaVersion -notmatch '^(?:openjdk|java)\s+21(?:\.|\s)') {
    throw "Java 21 is required. Detected: $javaVersion"
}

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$runServerSource = Join-Path $repositoryRoot 'server\scripts\run-server.ps1'
$binDirectory = Join-Path $InstallRoot 'bin'
New-Item -ItemType Directory -Path $binDirectory -Force | Out-Null
Copy-Item -LiteralPath $runServerSource -Destination (Join-Path $binDirectory 'run-server.ps1') -Force
[System.IO.File]::WriteAllText(
    (Join-Path $binDirectory 'java-path.txt'),
    $resolvedJavaPath,
    (New-Object System.Text.UTF8Encoding($false))
)

$powerShellPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$runServerPath = Join-Path $binDirectory 'run-server.ps1'
$arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$runServerPath`" -InstallRoot `"$InstallRoot`""
$action = New-ScheduledTaskAction -Execute $powerShellPath -Argument $arguments
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero)
$systemPrincipal = New-ScheduledTaskPrincipal `
    -UserId 'S-1-5-18' `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $systemPrincipal `
    -Description 'Money Snap Spring Boot origin; deployed by the dedicated GitHub Actions runner.' `
    -Force | Out-Null

$contractPath = Join-Path $InstallRoot 'expected-runner-label.txt'
[System.IO.File]::WriteAllText($contractPath, $ExpectedRunnerLabel)

Write-Output "Money Snap host task installed: $TaskName"
Write-Output "Register the GitHub Actions runner with labels: self-hosted, Windows, X64, $ExpectedRunnerLabel"
Write-Output 'Do not start the task before the first deployment has installed JAR and secret files.'

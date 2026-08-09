[CmdletBinding()]
param(
    [string]$InstallRoot = 'C:\ProgramData\MoneySnap\server'
)

$ErrorActionPreference = 'Stop'
$secretNames = @(
    'NEON_RUNTIME_DATABASE_URL',
    'NEON_RUNTIME_DATABASE_USERNAME',
    'NEON_RUNTIME_DATABASE_PASSWORD',
    'NEON_MIGRATION_DATABASE_URL',
    'NEON_MIGRATION_DATABASE_USERNAME',
    'NEON_MIGRATION_DATABASE_PASSWORD'
)

foreach ($secretName in $secretNames) {
    $secretPath = Join-Path $InstallRoot "secrets\$secretName"
    if (-not (Test-Path -LiteralPath $secretPath -PathType Leaf)) {
        throw "Required server secret file is missing: $secretName"
    }

    $secretValue = [System.IO.File]::ReadAllText($secretPath)
    if ([string]::IsNullOrWhiteSpace($secretValue)) {
        throw "Required server secret file is empty: $secretName"
    }

    [Environment]::SetEnvironmentVariable($secretName, $secretValue, 'Process')
}

$jarPath = Join-Path $InstallRoot 'current\moneysnap-server.jar'
if (-not (Test-Path -LiteralPath $jarPath -PathType Leaf)) {
    throw "Server JAR is missing: $jarPath"
}

$javaPathFile = Join-Path $InstallRoot 'bin\java-path.txt'
if (-not (Test-Path -LiteralPath $javaPathFile -PathType Leaf)) {
    throw "Configured Java path file is missing: $javaPathFile"
}
$javaPath = [System.IO.File]::ReadAllText($javaPathFile).Trim()
if ([string]::IsNullOrWhiteSpace($javaPath) -or
    -not (Test-Path -LiteralPath $javaPath -PathType Leaf)) {
    throw "Configured Java executable is missing: $javaPath"
}
$logDirectory = Join-Path $InstallRoot 'logs'
$logPath = Join-Path $logDirectory 'server.log'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

& $javaPath -jar $jarPath *>> $logPath
exit $LASTEXITCODE

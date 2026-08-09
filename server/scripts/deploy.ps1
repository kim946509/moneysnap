[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ArtifactPath,

    [Parameter(Mandatory)]
    [string]$ChecksumPath,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F]{7,64}$')]
    [string]$ReleaseId,

    [string]$InstallRoot = 'C:\ProgramData\MoneySnap\server',

    [string]$TaskName = 'MoneySnapServer',

    [uri]$HealthUri = 'http://127.0.0.1:8080/actuator/health'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'MoneySnap.Deployment.psm1') -Force

$secretNames = @(
    'NEON_RUNTIME_DATABASE_URL',
    'NEON_RUNTIME_DATABASE_USERNAME',
    'NEON_RUNTIME_DATABASE_PASSWORD',
    'NEON_MIGRATION_DATABASE_URL',
    'NEON_MIGRATION_DATABASE_USERNAME',
    'NEON_MIGRATION_DATABASE_PASSWORD'
)

function Get-RequiredSecrets {
    $values = @{}
    foreach ($secretName in $secretNames) {
        $value = [Environment]::GetEnvironmentVariable($secretName, 'Process')
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw "Required GitHub environment secret is missing: $secretName"
        }
        $values[$secretName] = $value
    }
    return $values
}

function Read-ExistingSecretFiles {
    param([string]$SecretDirectory)

    $values = @{}
    foreach ($secretName in $secretNames) {
        $path = Join-Path $SecretDirectory $secretName
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $values[$secretName] = [System.IO.File]::ReadAllText($path)
        }
    }
    return $values
}

function Stop-ServerTask {
    param([string]$Name)

    $task = Get-ScheduledTask -TaskName $Name -ErrorAction Stop
    if ($task.State -eq 'Running') {
        Stop-ScheduledTask -TaskName $Name
        for ($attempt = 0; $attempt -lt 20; $attempt++) {
            Start-Sleep -Milliseconds 500
            if ((Get-ScheduledTask -TaskName $Name).State -ne 'Running') {
                return
            }
        }
        throw "Scheduled task did not stop: $Name"
    }
}

function Start-ServerTask {
    param([string]$Name)

    Start-ScheduledTask -TaskName $Name
}

function Wait-ForHealthyServer {
    param(
        [uri]$Uri,
        [int]$Attempts = 45
    )

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            $health = Invoke-RestMethod -Uri $Uri -TimeoutSec 2
            Assert-MoneySnapHealthResponse -Health $health
            return
        }
        catch {
            if ($attempt -eq $Attempts) {
                throw
            }
            Start-Sleep -Seconds 1
        }
    }
}

$artifactHash = Assert-MoneySnapArtifactChecksum `
    -ArtifactPath $ArtifactPath `
    -ChecksumPath $ChecksumPath
$resolvedArtifact = (Resolve-Path -LiteralPath $ArtifactPath).Path

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -eq $task) {
    throw "Windows host is not bootstrapped. Scheduled task is missing: $TaskName"
}

$releasesDirectory = Join-Path $InstallRoot 'releases'
$releaseDirectory = Join-Path $releasesDirectory $ReleaseId
$releaseJar = Join-Path $releaseDirectory 'moneysnap-server.jar'
$releaseRunner = Join-Path $releaseDirectory 'run-server.ps1'
$currentDirectory = Join-Path $InstallRoot 'current'
$stateDirectory = Join-Path $InstallRoot 'state'
$secretDirectory = Join-Path $InstallRoot 'secrets'
$binDirectory = Join-Path $InstallRoot 'bin'
$currentStatePath = Join-Path $stateDirectory 'current-release.txt'
$previousStatePath = Join-Path $stateDirectory 'previous-release.txt'

New-Item -ItemType Directory -Path $releaseDirectory, $stateDirectory, $binDirectory -Force | Out-Null
Copy-Item -LiteralPath $resolvedArtifact -Destination $releaseJar -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'run-server.ps1') -Destination $releaseRunner -Force
if ((Get-FileHash -LiteralPath $releaseJar -Algorithm SHA256).Hash -ne $artifactHash) {
    throw 'Release JAR checksum changed while copying to the host'
}

$previousReleaseId = $null
if (Test-Path -LiteralPath $currentStatePath -PathType Leaf) {
    $previousReleaseId = [System.IO.File]::ReadAllText($currentStatePath).Trim()
}
$previousSecrets = Read-ExistingSecretFiles -SecretDirectory $secretDirectory
$newSecrets = Get-RequiredSecrets

$stopServer = {
    Stop-ServerTask -Name $TaskName
}.GetNewClosure()
$installRelease = {
    Write-MoneySnapSecretFiles `
        -SecretDirectory $secretDirectory `
        -SecretNames $secretNames `
        -Values $newSecrets
    Copy-MoneySnapReleaseToCurrent `
        -ReleaseJar $releaseJar `
        -ReleaseRunner $releaseRunner `
        -CurrentDirectory $currentDirectory `
        -BinDirectory $binDirectory
}.GetNewClosure()
$startServer = {
    Start-ServerTask -Name $TaskName
}.GetNewClosure()
$waitForHealthy = {
    Wait-ForHealthyServer -Uri $HealthUri
}.GetNewClosure()
$commitState = {
    if (-not [string]::IsNullOrWhiteSpace($previousReleaseId)) {
        [System.IO.File]::WriteAllText($previousStatePath, $previousReleaseId)
    }
    [System.IO.File]::WriteAllText($currentStatePath, $ReleaseId)
}.GetNewClosure()
$restorePrevious = {
    Restore-MoneySnapPreviousReleaseFiles `
        -PreviousReleaseId $previousReleaseId `
        -ReleasesDirectory $releasesDirectory `
        -CurrentDirectory $currentDirectory `
        -BinDirectory $binDirectory `
        -SecretDirectory $secretDirectory `
        -SecretNames $secretNames `
        -PreviousSecrets $previousSecrets
}.GetNewClosure()

Invoke-MoneySnapDeploymentOrchestration `
    -StopServer $stopServer `
    -InstallRelease $installRelease `
    -StartServer $startServer `
    -WaitForHealthy $waitForHealthy `
    -CommitState $commitState `
    -RestorePrevious $restorePrevious

Write-Output "Server deployment succeeded: release=$ReleaseId sha256=$artifactHash"

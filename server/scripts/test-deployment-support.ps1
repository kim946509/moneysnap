[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'MoneySnap.Deployment.psm1'
Import-Module $modulePath -Force

function Assert-Equal {
    param(
        [Parameter(Mandatory)]$Expected,
        [Parameter(Mandatory)]$Actual,
        [Parameter(Mandatory)][string]$Description
    )

    if ($Expected -ne $Actual) {
        throw "$Description. Expected=[$Expected] Actual=[$Actual]"
    }
}

$tempParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRoot = Join-Path $tempParent ("moneysnap-deployment-test-{0}" -f [guid]::NewGuid().ToString('N'))
$resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
if (-not $resolvedTestRoot.StartsWith($tempParent, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a test directory outside the system temp directory: $resolvedTestRoot"
}

New-Item -ItemType Directory -Path $resolvedTestRoot | Out-Null
try {
    $artifactPath = Join-Path $resolvedTestRoot 'moneysnap-server.jar'
    $checksumPath = Join-Path $resolvedTestRoot 'moneysnap-server.jar.sha256'
    [System.IO.File]::WriteAllText($artifactPath, 'tested-artifact')
    $expectedHash = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash
    [System.IO.File]::WriteAllText($checksumPath, "$expectedHash  moneysnap-server.jar`n")

    $verifiedHash = Assert-MoneySnapArtifactChecksum `
        -ArtifactPath $artifactPath `
        -ChecksumPath $checksumPath
    Assert-Equal $expectedHash $verifiedHash 'valid artifact checksum was not returned'

    [System.IO.File]::WriteAllText($artifactPath, 'tampered-artifact')
    $checksumRejected = $false
    try {
        Assert-MoneySnapArtifactChecksum `
            -ArtifactPath $artifactPath `
            -ChecksumPath $checksumPath | Out-Null
    }
    catch {
        $checksumRejected = $_.Exception.Message -match 'does not match'
    }
    Assert-Equal $true $checksumRejected 'tampered artifact was not rejected'

    $secretNames = @('RUNTIME_SECRET', 'MIGRATION_SECRET')
    $secretValues = @{
        RUNTIME_SECRET = 'runtime-value'
        MIGRATION_SECRET = 'migration-value'
    }
    $secretDirectory = Join-Path $resolvedTestRoot 'secrets'
    Write-MoneySnapSecretFiles `
        -SecretDirectory $secretDirectory `
        -SecretNames $secretNames `
        -Values $secretValues

    foreach ($secretName in $secretNames) {
        $secretPath = Join-Path $secretDirectory $secretName
        Assert-Equal $secretValues[$secretName] ([System.IO.File]::ReadAllText($secretPath)) "secret content mismatch: $secretName"
    }

    if ($env:OS -eq 'Windows_NT') {
        $directoryAcl = Get-Acl -LiteralPath $secretDirectory
        Assert-Equal $true $directoryAcl.AreAccessRulesProtected 'secret directory still inherits ACL entries'

        $expectedSids = @(
            'S-1-5-18',
            'S-1-5-32-544',
            [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        ) | Sort-Object -Unique
        $actualSids = @(
            $directoryAcl.Access |
                Where-Object AccessControlType -eq 'Allow' |
                ForEach-Object { $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value }
        ) | Sort-Object -Unique
        Assert-Equal ($expectedSids -join ',') ($actualSids -join ',') 'secret directory allowed principals differ from contract'
    }

    $releasesDirectory = Join-Path $resolvedTestRoot 'releases'
    $previousReleaseId = '0123456789abcdef'
    $previousReleaseDirectory = Join-Path $releasesDirectory $previousReleaseId
    $currentDirectory = Join-Path $resolvedTestRoot 'current'
    $binDirectory = Join-Path $resolvedTestRoot 'bin'
    New-Item -ItemType Directory -Path $previousReleaseDirectory, $currentDirectory, $binDirectory -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $previousReleaseDirectory 'moneysnap-server.jar'), 'previous-jar')
    [System.IO.File]::WriteAllText((Join-Path $previousReleaseDirectory 'run-server.ps1'), 'previous-runner')
    [System.IO.File]::WriteAllText((Join-Path $currentDirectory 'moneysnap-server.jar'), 'failed-jar')
    [System.IO.File]::WriteAllText((Join-Path $binDirectory 'run-server.ps1'), 'failed-runner')

    $previousSecrets = @{
        RUNTIME_SECRET = 'previous-runtime'
        MIGRATION_SECRET = 'previous-migration'
    }
    Restore-MoneySnapPreviousReleaseFiles `
        -PreviousReleaseId $previousReleaseId `
        -ReleasesDirectory $releasesDirectory `
        -CurrentDirectory $currentDirectory `
        -BinDirectory $binDirectory `
        -SecretDirectory $secretDirectory `
        -SecretNames $secretNames `
        -PreviousSecrets $previousSecrets

    Assert-Equal 'previous-jar' ([System.IO.File]::ReadAllText((Join-Path $currentDirectory 'moneysnap-server.jar'))) 'rollback did not restore the previous JAR'
    Assert-Equal 'previous-runner' ([System.IO.File]::ReadAllText((Join-Path $binDirectory 'run-server.ps1'))) 'rollback did not restore the previous runner script'
    Assert-Equal 'previous-runtime' ([System.IO.File]::ReadAllText((Join-Path $secretDirectory 'RUNTIME_SECRET'))) 'rollback did not restore previous runtime secret'
    Assert-Equal 'previous-migration' ([System.IO.File]::ReadAllText((Join-Path $secretDirectory 'MIGRATION_SECRET'))) 'rollback did not restore previous migration secret'

    Assert-MoneySnapHealthResponse -Health ([pscustomobject]@{ status = 'UP' })

    $downRejected = $false
    try {
        Assert-MoneySnapHealthResponse -Health ([pscustomobject]@{ status = 'DOWN' })
    }
    catch {
        $downRejected = $_.Exception.Message -match 'Unexpected health status'
    }
    Assert-Equal $true $downRejected 'DOWN health response was not rejected'

    $detailsRejected = $false
    try {
        Assert-MoneySnapHealthResponse -Health ([pscustomobject]@{
            status = 'UP'
            components = [pscustomobject]@{}
        })
    }
    catch {
        $detailsRejected = $_.Exception.Message -match 'component details'
    }
    Assert-Equal $true $detailsRejected 'component-exposing health response was not rejected'

    $healthyScenario = @{
        Events = New-Object System.Collections.Generic.List[string]
    }
    Invoke-MoneySnapDeploymentOrchestration `
        -StopServer ({ [void]$healthyScenario.Events.Add('stop') }.GetNewClosure()) `
        -InstallRelease ({ [void]$healthyScenario.Events.Add('install') }.GetNewClosure()) `
        -StartServer ({ [void]$healthyScenario.Events.Add('start') }.GetNewClosure()) `
        -WaitForHealthy ({ [void]$healthyScenario.Events.Add('health') }.GetNewClosure()) `
        -CommitState ({ [void]$healthyScenario.Events.Add('commit') }.GetNewClosure()) `
        -RestorePrevious ({ [void]$healthyScenario.Events.Add('restore') }.GetNewClosure())
    Assert-Equal 'stop,install,start,health,commit' ($healthyScenario.Events -join ',') 'healthy deployment orchestration order is invalid'

    $failedScenario = @{
        Events = New-Object System.Collections.Generic.List[string]
        HealthCalls = 0
    }
    $originalHealthFailureRethrown = $false
    try {
        Invoke-MoneySnapDeploymentOrchestration `
            -StopServer ({ [void]$failedScenario.Events.Add('stop') }.GetNewClosure()) `
            -InstallRelease ({ [void]$failedScenario.Events.Add('install') }.GetNewClosure()) `
            -StartServer ({ [void]$failedScenario.Events.Add('start') }.GetNewClosure()) `
            -WaitForHealthy ({
                [void]$failedScenario.Events.Add('health')
                $failedScenario.HealthCalls++
                if ($failedScenario.HealthCalls -eq 1) {
                    throw 'simulated unhealthy release'
                }
            }.GetNewClosure()) `
            -CommitState ({ [void]$failedScenario.Events.Add('commit') }.GetNewClosure()) `
            -RestorePrevious ({ [void]$failedScenario.Events.Add('restore') }.GetNewClosure())
    }
    catch {
        $originalHealthFailureRethrown = $_.Exception.Message -match 'simulated unhealthy release'
    }
    Assert-Equal $true $originalHealthFailureRethrown 'original health failure was not rethrown after rollback'
    Assert-Equal 'stop,install,start,health,stop,restore,start,health' ($failedScenario.Events -join ',') 'unhealthy deployment did not rollback before state commit'

    Write-Output 'Money Snap deployment support tests: OK'
}
finally {
    $cleanupTarget = [System.IO.Path]::GetFullPath($resolvedTestRoot)
    if ($cleanupTarget.StartsWith($tempParent, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $cleanupTarget) -like 'moneysnap-deployment-test-*') {
        Remove-Item -LiteralPath $cleanupTarget -Recurse -Force -ErrorAction SilentlyContinue
    }
}

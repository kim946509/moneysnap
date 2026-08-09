Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-MoneySnapArtifactChecksum {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ArtifactPath,
        [Parameter(Mandatory)][string]$ChecksumPath
    )

    if (-not (Test-Path -LiteralPath $ArtifactPath -PathType Leaf)) {
        throw "Deployment artifact is missing: $ArtifactPath"
    }
    if (-not (Test-Path -LiteralPath $ChecksumPath -PathType Leaf)) {
        throw "Artifact checksum manifest is missing: $ChecksumPath"
    }

    $resolvedArtifact = (Resolve-Path -LiteralPath $ArtifactPath).Path
    $resolvedChecksum = (Resolve-Path -LiteralPath $ChecksumPath).Path
    $checksumLine = [System.IO.File]::ReadAllText($resolvedChecksum).Trim()
    if ($checksumLine -notmatch '^([0-9a-fA-F]{64})\s+') {
        throw 'JAR checksum manifest has an invalid format'
    }

    $expectedHash = $Matches[1].ToUpperInvariant()
    $actualHash = (Get-FileHash -LiteralPath $resolvedArtifact -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) {
        throw 'JAR checksum does not match the tested build artifact'
    }

    return $actualHash
}

function Protect-MoneySnapSecretDirectory {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SecretDirectory)

    New-Item -ItemType Directory -Path $SecretDirectory -Force | Out-Null

    $acl = Get-Acl -LiteralPath $SecretDirectory
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($existingRule in @($acl.Access)) {
        [void]$acl.RemoveAccessRuleSpecific($existingRule)
    }
    $currentUserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    foreach ($sidValue in @('S-1-5-18', 'S-1-5-32-544', $currentUserSid) | Select-Object -Unique) {
        $sid = New-Object System.Security.Principal.SecurityIdentifier($sidValue)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $sid,
            'FullControl',
            'ContainerInherit,ObjectInherit',
            'None',
            'Allow'
        )
        [void]$acl.AddAccessRule($rule)
    }
    [System.IO.Directory]::SetAccessControl($SecretDirectory, $acl)

    $appliedAcl = Get-Acl -LiteralPath $SecretDirectory
    if (-not $appliedAcl.AreAccessRulesProtected) {
        throw "Secret directory ACL still inherits parent permissions: $SecretDirectory"
    }
}

function Write-MoneySnapSecretFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SecretDirectory,
        [Parameter(Mandatory)][string[]]$SecretNames,
        [Parameter(Mandatory)][hashtable]$Values
    )

    foreach ($secretName in $SecretNames) {
        if (-not $Values.ContainsKey($secretName) -or
            [string]::IsNullOrWhiteSpace([string]$Values[$secretName])) {
            throw "Secret value is missing: $secretName"
        }
    }

    # The directory must be protected before any credential bytes are written.
    Protect-MoneySnapSecretDirectory -SecretDirectory $SecretDirectory

    foreach ($secretName in $SecretNames) {
        $path = Join-Path $SecretDirectory $secretName
        $temporaryPath = Join-Path $SecretDirectory "$secretName.next"
        [System.IO.File]::WriteAllText(
            $temporaryPath,
            [string]$Values[$secretName],
            (New-Object System.Text.UTF8Encoding($false))
        )
        Move-Item -LiteralPath $temporaryPath -Destination $path -Force
    }
}

function Copy-MoneySnapReleaseToCurrent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ReleaseJar,
        [Parameter(Mandatory)][string]$ReleaseRunner,
        [Parameter(Mandatory)][string]$CurrentDirectory,
        [Parameter(Mandatory)][string]$BinDirectory
    )

    foreach ($requiredFile in @($ReleaseJar, $ReleaseRunner)) {
        if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
            throw "Release file is missing: $requiredFile"
        }
    }

    New-Item -ItemType Directory -Path $CurrentDirectory, $BinDirectory -Force | Out-Null
    $temporaryJar = Join-Path $CurrentDirectory 'moneysnap-server.jar.next'
    $currentJar = Join-Path $CurrentDirectory 'moneysnap-server.jar'
    $temporaryRunner = Join-Path $BinDirectory 'run-server.ps1.next'
    $currentRunner = Join-Path $BinDirectory 'run-server.ps1'

    Copy-Item -LiteralPath $ReleaseJar -Destination $temporaryJar -Force
    Copy-Item -LiteralPath $ReleaseRunner -Destination $temporaryRunner -Force
    Move-Item -LiteralPath $temporaryJar -Destination $currentJar -Force
    Move-Item -LiteralPath $temporaryRunner -Destination $currentRunner -Force
}

function Restore-MoneySnapPreviousReleaseFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PreviousReleaseId,
        [Parameter(Mandatory)][string]$ReleasesDirectory,
        [Parameter(Mandatory)][string]$CurrentDirectory,
        [Parameter(Mandatory)][string]$BinDirectory,
        [Parameter(Mandatory)][string]$SecretDirectory,
        [Parameter(Mandatory)][string[]]$SecretNames,
        [Parameter(Mandatory)][hashtable]$PreviousSecrets
    )

    if ([string]::IsNullOrWhiteSpace($PreviousReleaseId)) {
        throw 'Deployment failed and no previous release is available'
    }
    if ($PreviousSecrets.Count -ne $SecretNames.Count) {
        throw "Previous release secret set is incomplete: $PreviousReleaseId"
    }

    $previousReleaseDirectory = Join-Path $ReleasesDirectory $PreviousReleaseId
    $previousJar = Join-Path $previousReleaseDirectory 'moneysnap-server.jar'
    $previousRunner = Join-Path $previousReleaseDirectory 'run-server.ps1'
    Copy-MoneySnapReleaseToCurrent `
        -ReleaseJar $previousJar `
        -ReleaseRunner $previousRunner `
        -CurrentDirectory $CurrentDirectory `
        -BinDirectory $BinDirectory
    Write-MoneySnapSecretFiles `
        -SecretDirectory $SecretDirectory `
        -SecretNames $SecretNames `
        -Values $PreviousSecrets
}

function Assert-MoneySnapHealthResponse {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Health)

    if ($null -eq $Health -or
        $Health.PSObject.Properties.Name -notcontains 'status' -or
        $Health.status -ne 'UP') {
        $actualStatus = if ($null -eq $Health) { '<null>' } else { [string]$Health.status }
        throw "Unexpected health status: $actualStatus"
    }
    if ($Health.PSObject.Properties.Name -contains 'components') {
        throw 'Health response exposed component details'
    }
}

function Invoke-MoneySnapDeploymentOrchestration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock]$StopServer,
        [Parameter(Mandatory)][scriptblock]$InstallRelease,
        [Parameter(Mandatory)][scriptblock]$StartServer,
        [Parameter(Mandatory)][scriptblock]$WaitForHealthy,
        [Parameter(Mandatory)][scriptblock]$CommitState,
        [Parameter(Mandatory)][scriptblock]$RestorePrevious
    )

    & $StopServer
    try {
        & $InstallRelease
        & $StartServer
        & $WaitForHealthy
        & $CommitState
    }
    catch {
        $deploymentError = $_
        try {
            & $StopServer
            & $RestorePrevious
            & $StartServer
            & $WaitForHealthy
        }
        catch {
            Write-Warning "Rollback failed: $($_.Exception.Message)"
        }
        throw $deploymentError
    }
}

Export-ModuleMember -Function @(
    'Assert-MoneySnapArtifactChecksum',
    'Protect-MoneySnapSecretDirectory',
    'Write-MoneySnapSecretFiles',
    'Copy-MoneySnapReleaseToCurrent',
    'Restore-MoneySnapPreviousReleaseFiles',
    'Assert-MoneySnapHealthResponse',
    'Invoke-MoneySnapDeploymentOrchestration'
)

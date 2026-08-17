$ErrorActionPreference = 'Stop'

$validatorPath = Join-Path $PSScriptRoot 'validate-visual-baseline.ps1'
$manifestPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'VisualReferences\manifest.json'
$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("moneysnap-visual-contract-" + [guid]::NewGuid())
$temporaryManifest = Join-Path $temporaryDirectory 'manifest.json'
$powerShellPath = (Get-Process -Id $PID).Path

function Write-TestManifest {
    param([Parameter(Mandatory)] $Manifest)

    $Manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $temporaryManifest -Encoding utf8
}

function Invoke-Validator {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $powerShellPath -NoProfile -ExecutionPolicy Bypass -File $validatorPath -ManifestPath $temporaryManifest 1> $null 2> $null
        return $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Assert-ValidatorPasses {
    param([Parameter(Mandatory)] $Manifest, [Parameter(Mandatory)] [string] $Case)

    Write-TestManifest $Manifest
    if ((Invoke-Validator) -ne 0) {
        throw "Expected validator to accept: $Case"
    }
}

function Assert-ValidatorRejects {
    param([Parameter(Mandatory)] $Manifest, [Parameter(Mandatory)] [string] $Case)

    Write-TestManifest $Manifest
    if ((Invoke-Validator) -eq 0) {
        throw "Expected validator to reject: $Case"
    }
}

function Read-ManifestCopy {
    Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
}

New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null
try {
    Assert-ValidatorPasses (Read-ManifestCopy) 'reviewed manifest'

    $homeCrop = Read-ManifestCopy
    $homeCrop.figma.screens.home | Add-Member -NotePropertyName comparisonCrop -NotePropertyValue ([pscustomobject]@{
        x = 0
        y = 0
        width = 393
        height = 852
    })
    Assert-ValidatorRejects $homeCrop 'Home must remain a full-frame comparison'

    $myCrop = Read-ManifestCopy
    $myCrop.figma.screens.my | Add-Member -NotePropertyName comparisonCrop -NotePropertyValue ([pscustomobject]@{
        x = 0
        y = 0
        width = 393
        height = 852
    })
    Assert-ValidatorRejects $myCrop 'My must remain a full-frame comparison'

    $driftedApprovedHash = Read-ManifestCopy
    $driftedApprovedHash.figma.screens.'record-category'.sha256 =
        $driftedApprovedHash.figma.screens.'record-category'.sha256.ToUpperInvariant()
    Assert-ValidatorRejects $driftedApprovedHash 'record category approved SHA-256 is pinned exactly'

    foreach ($invalidValue in @('0', $false)) {
        $invalidCrop = Read-ManifestCopy
        $invalidCrop.figma.screens.'record-category'.comparisonCrop.x = $invalidValue
        Assert-ValidatorRejects $invalidCrop "comparisonCrop rejects $($invalidValue.GetType().Name)"
    }

    $decimalCrop = Read-ManifestCopy
    $decimalJson = $decimalCrop | ConvertTo-Json -Depth 20
    $decimalJson = $decimalJson -replace '("x"\s*:\s*)0(\s*,\s*"y"\s*:\s*604)', '${1}0.0${2}'
    Set-Content -LiteralPath $temporaryManifest -Value $decimalJson -Encoding utf8
    if ((Invoke-Validator) -eq 0) {
        throw 'Expected validator to reject: comparisonCrop rejects a decimal JSON number'
    }

    Write-Output 'MoneySnap visual baseline validator regression probes: OK'
}
finally {
    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
}

param(
    [string] $ManifestPath
)

$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [Parameter(Mandatory)]
        [bool] $Condition,

        [Parameter(Mandatory)]
        [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Test-JsonInteger {
    param([Parameter(Mandatory)] $Value)

    return [System.Type]::GetTypeCode($Value.GetType()) -in @(
        [System.TypeCode]::Byte,
        [System.TypeCode]::SByte,
        [System.TypeCode]::Int16,
        [System.TypeCode]::UInt16,
        [System.TypeCode]::Int32,
        [System.TypeCode]::UInt32,
        [System.TypeCode]::Int64,
        [System.TypeCode]::UInt64
    )
}

$iosRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = Split-Path -Parent $iosRoot
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $iosRoot 'VisualReferences\manifest.json'
}

Assert-True (Test-Path -LiteralPath $ManifestPath) 'Visual baseline manifest is missing.'

$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
Assert-True ($manifest.figma.fileKey -eq 'IDNeYlc3584NY9YhsyUQYE') 'Unexpected Figma file key.'
Assert-True ($manifest.figma.screens.home.nodeId -eq '9:2') 'Unexpected Home Figma node ID.'
Assert-True ($manifest.figma.screens.my.nodeId -eq '77:798') 'Unexpected My Figma node ID.'
Assert-True ($manifest.figma.screens.'record-category'.nodeId -eq '108:465') 'Unexpected record category Figma node ID.'
Assert-True ($manifest.figma.screens.'record-amount'.nodeId -eq '108:549') 'Unexpected record amount Figma node ID.'
Assert-True (
    $manifest.figma.screens.'record-category'.sha256 -ceq 'ada9814549f1bab323cbfc4040379156ce0757f41b9f50fc4f75927c5fafa47f'
) 'Unexpected record category approved reference checksum.'
Assert-True (
    $manifest.figma.screens.'record-amount'.sha256 -ceq '26e378b06fa7539bfbb8ff4a3124678853b3e87a8f4e15399fefbf2b0eeb14ac'
) 'Unexpected record amount approved reference checksum.'
Assert-True (
    $manifest.figma.screens.home.PSObject.Properties.Name -notcontains 'comparisonCrop'
) 'Home must remain a full-frame comparison without comparisonCrop.'
Assert-True (
    $manifest.figma.screens.my.PSObject.Properties.Name -notcontains 'comparisonCrop'
) 'My must remain a full-frame comparison without comparisonCrop.'
Assert-True ($manifest.viewport.width -eq 393 -and $manifest.viewport.height -eq 852) 'Visual viewport must be 393x852.'
Assert-True ($manifest.bundleIdentifier -eq 'com.ansandy.moneysnap') 'Unexpected Bundle ID.'
Assert-True ($manifest.simulator.xcode -eq '16.4') 'Visual Xcode baseline must be 16.4.'
Assert-True ($manifest.simulator.device -eq 'iPhone 16') 'Visual device baseline must be iPhone 16.'
Assert-True ($manifest.simulator.os -eq '18.5') 'Visual OS baseline must be iOS 18.5.'
Assert-True ($manifest.comparison.mode -eq 'threshold') 'Visual diff must fail CI when Home parity regresses.'
Assert-True ($manifest.comparison.maximumMeanAbsoluteError -gt 0 -and $manifest.comparison.maximumMeanAbsoluteError -le 0.05) 'Visual MAE threshold must be reviewed and no greater than 0.05.'
Assert-True ($manifest.comparison.maximumMismatchedPixelRatio -gt 0 -and $manifest.comparison.maximumMismatchedPixelRatio -le 0.43) 'Visual mismatched-pixel threshold must be reviewed and no greater than 0.43.'

$scenarioNames = @($manifest.scenarios)
Assert-True ($scenarioNames.Count -eq 4) 'Visual manifest must contain Home, My, record category and record amount scenarios.'
Assert-True (
    $scenarioNames[0] -eq 'home' -and
    $scenarioNames[1] -eq 'my' -and
    $scenarioNames[2] -eq 'record-category' -and
    $scenarioNames[3] -eq 'record-amount'
) 'Visual scenarios must keep the reviewed home, my, record-category, record-amount order.'
$screenNames = @($manifest.figma.screens.PSObject.Properties.Name)
$orderedScreenSet = ($screenNames | Sort-Object) -join ','
$orderedScenarioSet = ($scenarioNames | Sort-Object) -join ','
Assert-True ($orderedScreenSet -eq $orderedScenarioSet) 'Visual scenario and Figma screen sets must match exactly.'

foreach ($screenName in $scenarioNames) {
    $screen = $manifest.figma.screens.$screenName
    $referencePath = Join-Path $iosRoot $screen.reference
    Assert-True (Test-Path -LiteralPath $referencePath) "$screenName Figma reference image is missing."
    $referenceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $referencePath).Hash.ToLowerInvariant()
    Assert-True ($referenceHash -eq $screen.sha256) "$screenName Figma reference checksum does not match the manifest."

    Add-Type -AssemblyName System.Drawing
    $referenceImage = [System.Drawing.Image]::FromFile($referencePath)
    try {
        Assert-True ($referenceImage.Width -eq 393 -and $referenceImage.Height -eq 852) "$screenName Figma reference image must be 393x852."
    }
    finally {
        $referenceImage.Dispose()
    }

    if ($null -ne $screen.comparisonCrop) {
        $crop = $screen.comparisonCrop
        foreach ($coordinateName in @('x', 'y', 'width', 'height')) {
            $coordinateProperty = $crop.PSObject.Properties[$coordinateName]
            Assert-True ($null -ne $coordinateProperty) "$screenName comparison crop must contain $coordinateName."
            Assert-True (Test-JsonInteger $coordinateProperty.Value) "$screenName comparison crop $coordinateName must be an integer JSON number."
        }
        Assert-True (
            $crop.x -ge 0 -and $crop.y -ge 0 -and
            $crop.width -gt 0 -and $crop.height -gt 0 -and
            $crop.x + $crop.width -le $manifest.viewport.width -and
            $crop.y + $crop.height -le $manifest.viewport.height
        ) "$screenName comparison crop must be positive and stay inside the 393x852 source frame."
    }
}

$categoryCrop = $manifest.figma.screens.'record-category'.comparisonCrop
Assert-True (
    $categoryCrop.x -eq 0 -and $categoryCrop.y -eq 604 -and
    $categoryCrop.width -eq 393 -and $categoryCrop.height -eq 248
) 'Record category comparison must exclude the out-of-scope photo header and cover the reviewed lower component.'
$amountCrop = $manifest.figma.screens.'record-amount'.comparisonCrop
Assert-True (
    $amountCrop.x -eq 0 -and $amountCrop.y -eq 460 -and
    $amountCrop.width -eq 393 -and $amountCrop.height -eq 392
) 'Record amount comparison must exclude the out-of-scope photo header and cover the reviewed lower component.'

$foodAsset = Join-Path $iosRoot 'MoneySnap\Assets.xcassets\FoodSnap.imageset\food-snap.png'
$cafeAsset = Join-Path $iosRoot 'MoneySnap\Assets.xcassets\CafeSnap.imageset\cafe-snap.png'
$fontAsset = Join-Path $iosRoot 'MoneySnap\Resources\Fonts\NotoSansKR-VariableFont_wght.ttf'
Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $foodAsset).Hash.ToLowerInvariant() -eq $manifest.assets.foodSnap.sha256) 'Food Figma asset checksum mismatch.'
Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $cafeAsset).Hash.ToLowerInvariant() -eq $manifest.assets.cafeSnap.sha256) 'Cafe Figma asset checksum mismatch.'
Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $fontAsset).Hash.ToLowerInvariant() -eq $manifest.assets.notoSansKr.sha256) 'Noto Sans KR checksum mismatch.'

$appTab = Get-Content -Raw -LiteralPath (Join-Path $iosRoot 'MoneySnap\App\AppTab.swift')
Assert-True ($appTab -match 'enum\s+AppTab\s*:\s*[^\r\n{]*\bSendable\b') 'AppTab must conform to Sendable for Swift 6.'

$project = Get-Content -Raw -LiteralPath (Join-Path $iosRoot 'MoneySnap.xcodeproj\project.pbxproj')
Assert-True ($project -match 'PRODUCT_BUNDLE_IDENTIFIER = com\.ansandy\.moneysnap;') 'Final Bundle ID is missing from the app target.'

$resolver = Get-Content -Raw -LiteralPath (Join-Path $iosRoot 'scripts\resolve-simulator.sh')
Assert-True ($resolver -match 'MONEYSNAP_SIMULATOR_DEVICE') 'Simulator resolver must use the fixed device contract.'
Assert-True ($resolver -match 'MONEYSNAP_SIMULATOR_OS') 'Simulator resolver must use the fixed OS contract.'

$capture = Get-Content -Raw -LiteralPath (Join-Path $iosRoot 'scripts\capture-visual-baseline.sh')
Assert-True ($capture -match 'simctl\s+io') 'Visual capture must use the iOS Simulator screenshot API.'
Assert-True ($capture -match 'visual-diff\.swift') 'Visual capture must create overlay and diff evidence.'
Assert-True ($capture -match 'MONEYSNAP_VISUAL_SCENARIO') 'Visual capture must select the deterministic Home or My scenario.'
Assert-True ($capture -match '--maximum-mean-absolute-error') 'Visual capture must enforce the reviewed MAE threshold.'
Assert-True ($capture -match '--maximum-mismatched-pixel-ratio') 'Visual capture must enforce the reviewed mismatched-pixel threshold.'
Assert-True ($capture -match '--scenario') 'Visual report must identify every manifest scenario.'
Assert-True ($capture -match '--figma-node-id') 'Visual report must identify every Figma node.'
Assert-True ($capture -match '--source-reference-sha256') 'Visual report must identify every approved source reference checksum.'
Assert-True ([regex]::Matches($capture, '(?m)^xcodebuild\s+\\?$').Count -eq 1) 'Visual capture must build the app exactly once.'
Assert-True ([regex]::Matches($capture, 'simctl\s+install').Count -eq 1) 'Visual capture must install the app exactly once.'
Assert-True ($capture -match 'for\s+visual_scenario\s+in') 'Visual capture must iterate through the ordered manifest scenarios.'
Assert-True ($capture -match 'visual_failures') 'Visual capture must aggregate scenario failures after capturing all evidence.'
Assert-True ($capture -match 'read\s+-r\s+visual_scenario\s+\|\|\s+\[\[\s+-n\s+"\$\{visual_scenario\}"\s+\]\]') 'Visual capture must preserve the final manifest scenario when parser output has no trailing newline.'

$visualDiff = Get-Content -Raw -LiteralPath (Join-Path $iosRoot 'scripts\visual-diff.swift')
Assert-True ($visualDiff -match '"scenario"\s*:\s*configuration\.scenario') 'Visual report is missing scenario identity.'
Assert-True ($visualDiff -match '"figmaNodeId"\s*:\s*configuration\.figmaNodeID') 'Visual report is missing Figma node identity.'
Assert-True ($visualDiff -match '"sourceReferenceSha256"\s*:\s*configuration\.sourceReferenceSHA256') 'Visual report is missing source reference checksum identity.'

$todayView = Get-Content -Raw -LiteralPath (Join-Path $iosRoot 'MoneySnap\Features\Home\TodaySnapView.swift')
Assert-True ($todayView -match 'accessibilityIdentifier\("screen\.home"\)') 'Home screen accessibility identifier is missing.'
Assert-True ($todayView -match 'accessibilityIdentifier\("home\.total"\)') 'Home total accessibility identifier is missing.'
$myView = Get-Content -Raw -LiteralPath (Join-Path $iosRoot 'MoneySnap\Features\Profile\MySettingsView.swift')
Assert-True ($myView -match 'accessibilityIdentifier\("screen\.my"\)') 'My screen accessibility identifier is missing.'
$tabBar = Get-Content -Raw -LiteralPath (Join-Path $iosRoot 'MoneySnap\VisualSystem\MoneySnapTabBar.swift')
Assert-True ($tabBar -match 'accessibilityIdentifier\("tab\.\\\(tab\.rawValue\)"\)') 'Tab buttons must expose stable tab.<name> identifiers.'

Assert-True ($todayView -match 'HStack\(spacing:\s*28\)\s*\{\s*ForEach\(summary\.recentEntries\)') 'Recent Snap rows must use the Figma 28-point two-column gap.'

$workflow = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot '.github\workflows\ios-ci.yml')
Assert-True ($workflow -match 'DEVELOPER_DIR:\s*/Applications/Xcode_16\.4\.app/Contents/Developer') 'iOS CI must pin Xcode 16.4.'
Assert-True ($workflow -match 'MONEYSNAP_SIMULATOR_DEVICE:\s*"?iPhone 16"?') 'iOS CI must pin iPhone 16.'
Assert-True ($workflow -match 'MONEYSNAP_SIMULATOR_OS:\s*"?18\.5"?') 'iOS CI must pin iOS 18.5.'
Assert-True ($workflow -match 'capture-visual-baseline\.sh') 'iOS CI must capture visual baseline evidence.'
Assert-True ([regex]::Matches($workflow, 'capture-visual-baseline\.sh').Count -eq 1) 'iOS CI must invoke the build-once visual runner exactly once.'
Assert-True ($workflow -notmatch 'MONEYSNAP_VISUAL_SCENARIO=(?:home|my)') 'iOS CI must let the manifest drive the ordered scenarios.'
Assert-True ($workflow -match 'ios-visual-evidence-') 'iOS CI must upload named visual evidence.'

Write-Output 'MoneySnap iOS visual baseline contract: OK'

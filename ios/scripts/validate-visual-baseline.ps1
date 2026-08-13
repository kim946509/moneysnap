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

$iosRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = Split-Path -Parent $iosRoot
$manifestPath = Join-Path $iosRoot 'VisualReferences\manifest.json'

Assert-True (Test-Path -LiteralPath $manifestPath) 'Visual baseline manifest is missing.'

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
Assert-True ($manifest.figma.fileKey -eq 'IDNeYlc3584NY9YhsyUQYE') 'Unexpected Figma file key.'
Assert-True ($manifest.figma.screens.home.nodeId -eq '9:2') 'Unexpected Home Figma node ID.'
Assert-True ($manifest.figma.screens.my.nodeId -eq '77:798') 'Unexpected My Figma node ID.'
Assert-True ($manifest.viewport.width -eq 393 -and $manifest.viewport.height -eq 852) 'Visual viewport must be 393x852.'
Assert-True ($manifest.bundleIdentifier -eq 'com.ansandy.moneysnap') 'Unexpected Bundle ID.'
Assert-True ($manifest.simulator.xcode -eq '16.4') 'Visual Xcode baseline must be 16.4.'
Assert-True ($manifest.simulator.device -eq 'iPhone 16') 'Visual device baseline must be iPhone 16.'
Assert-True ($manifest.simulator.os -eq '18.5') 'Visual OS baseline must be iOS 18.5.'
Assert-True ($manifest.comparison.mode -eq 'threshold') 'Visual diff must fail CI when Home parity regresses.'
Assert-True ($manifest.comparison.maximumMeanAbsoluteError -gt 0 -and $manifest.comparison.maximumMeanAbsoluteError -le 0.05) 'Visual MAE threshold must be reviewed and no greater than 0.05.'
Assert-True ($manifest.comparison.maximumMismatchedPixelRatio -gt 0 -and $manifest.comparison.maximumMismatchedPixelRatio -le 0.43) 'Visual mismatched-pixel threshold must be reviewed and no greater than 0.43.'

$scenarioNames = @($manifest.scenarios)
Assert-True ($scenarioNames.Count -eq 2) 'Visual manifest must contain exactly Home and My scenarios.'
Assert-True ($scenarioNames[0] -eq 'home' -and $scenarioNames[1] -eq 'my') 'Visual scenarios must keep the reviewed home, my order.'
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
}

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
Assert-True ([regex]::Matches($capture, '(?m)^xcodebuild\s+\\?$').Count -eq 1) 'Visual capture must build the app exactly once.'
Assert-True ([regex]::Matches($capture, 'simctl\s+install').Count -eq 1) 'Visual capture must install the app exactly once.'
Assert-True ($capture -match 'for\s+visual_scenario\s+in') 'Visual capture must iterate through the ordered manifest scenarios.'
Assert-True ($capture -match 'visual_failures') 'Visual capture must aggregate scenario failures after capturing all evidence.'
Assert-True ($capture -match 'read\s+-r\s+visual_scenario\s+\|\|\s+\[\[\s+-n\s+"\$\{visual_scenario\}"\s+\]\]') 'Visual capture must preserve the final manifest scenario when parser output has no trailing newline.'

$visualSupport = Get-Content -Raw -LiteralPath (Join-Path $iosRoot 'MoneySnap\App\VisualTestSupport.swift')
foreach ($scenarioName in $scenarioNames) {
    Assert-True ($visualSupport -match "case\s+$([regex]::Escape($scenarioName))\b") "Visual DEBUG allowlist is missing scenario $scenarioName."
}

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

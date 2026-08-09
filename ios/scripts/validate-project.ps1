$ErrorActionPreference = 'Stop'

$iosRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$projectFile = Join-Path $iosRoot 'MoneySnap.xcodeproj\project.pbxproj'
$schemeFile = Join-Path $iosRoot 'MoneySnap.xcodeproj\xcshareddata\xcschemes\MoneySnap.xcscheme'
$requiredFiles = @(
    $projectFile,
    $schemeFile,
    (Join-Path $iosRoot 'MoneySnap\App\MoneySnapApp.swift'),
    (Join-Path $iosRoot 'MoneySnap\App\AppShellView.swift'),
    (Join-Path $iosRoot 'MoneySnap\App\AppTab.swift'),
    (Join-Path $iosRoot 'MoneySnap\App\RouterPath.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Placeholder\PlaceholderView.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Home\TodaySnapModels.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Home\SnapJournalClient.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Home\TodaySnapViewModel.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Home\TodaySnapView.swift'),
    (Join-Path $iosRoot 'MoneySnap\Info.plist'),
    (Join-Path $iosRoot 'MoneySnap\Resources\Fonts\NotoSansKR-VariableFont_wght.ttf'),
    (Join-Path $iosRoot 'MoneySnap\Assets.xcassets\FoodSnap.imageset\food-snap.png'),
    (Join-Path $iosRoot 'MoneySnap\Assets.xcassets\CafeSnap.imageset\cafe-snap.png'),
    (Join-Path $iosRoot 'MoneySnapTests\AppShellTests.swift'),
    (Join-Path $iosRoot 'MoneySnapTests\TodaySnapViewModelTests.swift')
)

$missingFiles = $requiredFiles | Where-Object { -not (Test-Path -LiteralPath $_) }
if ($missingFiles) {
    throw "Missing iOS project files: $($missingFiles -join ', ')"
}

$project = Get-Content -LiteralPath $projectFile -Raw
$scheme = [xml](Get-Content -LiteralPath $schemeFile -Raw)
$assets = Get-Content -LiteralPath (Join-Path $iosRoot 'MoneySnap\Assets.xcassets\Contents.json') -Raw | ConvertFrom-Json

if ($project -notmatch 'PRODUCT_BUNDLE_IDENTIFIER = com\.ansandy\.moneysnap;') {
    throw 'Expected bundle identifier is missing.'
}
if ($project -notmatch 'IPHONEOS_DEPLOYMENT_TARGET = 17\.0;') {
    throw 'Expected iOS 17 deployment target is missing.'
}
if ($project -notmatch 'productType = "com\.apple\.product-type\.application";' -or
    $project -notmatch 'productType = "com\.apple\.product-type\.bundle\.unit-test";') {
    throw 'Application or unit-test target is missing.'
}
if ($project -match 'DEVELOPMENT_TEAM = [A-Z0-9]+;') {
    throw 'A signing team must not be committed before Apple setup.'
}

$definitionMatches = [regex]::Matches(
    $project,
    '(?m)^\s*([A-F0-9]{24})(?: /\*.*?\*/)? = \{\r?\n\s*isa ='
)
$definitionIDs = @($definitionMatches | ForEach-Object { $_.Groups[1].Value })
if ($definitionIDs.Count -ne @($definitionIDs | Select-Object -Unique).Count) {
    throw 'Duplicate PBX object definitions were found.'
}

$invalidObjectIDs = [regex]::Matches($project, '(?m)^\s*([A-Z0-9]{24})') |
    ForEach-Object { $_.Groups[1].Value } |
    Where-Object { $_ -notmatch '^[A-F0-9]{24}$' } |
    Select-Object -Unique
if ($invalidObjectIDs) {
    throw "Invalid PBX object identifiers: $($invalidObjectIDs -join ', ')"
}

$expectedSourceNames = @(
    'MoneySnapApp.swift',
    'AppShellView.swift',
    'AppTab.swift',
    'RouterPath.swift',
    'PlaceholderView.swift',
    'TodaySnapModels.swift',
    'SnapJournalClient.swift',
    'TodaySnapViewModel.swift',
    'TodaySnapView.swift',
    'AppShellTests.swift',
    'TodaySnapViewModelTests.swift'
)
foreach ($sourceName in $expectedSourceNames) {
    if ($project -notmatch [regex]::Escape("path = $sourceName;")) {
        throw "PBX project does not reference $sourceName."
    }
}

if ($scheme.Scheme.BuildAction.BuildActionEntries.BuildActionEntry.Count -ne 2) {
    throw 'Shared scheme must build the app and unit-test targets.'
}
if ($assets.info.author -ne 'xcode' -or $assets.info.version -ne 1) {
    throw 'Asset catalog metadata is invalid.'
}

$infoPlist = [xml](Get-Content -LiteralPath (Join-Path $iosRoot 'MoneySnap\Info.plist') -Raw)
if ($infoPlist.plist.dict.array.string -notcontains 'NotoSansKR-VariableFont_wght.ttf') {
    throw 'Noto Sans KR must be registered in UIAppFonts.'
}

Write-Output 'MoneySnap iOS project static validation: OK'

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
    (Join-Path $iosRoot 'MoneySnap\Features\Home\TodayCanvasLayout.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Home\TodaySnapCardViews.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Authentication\AuthenticationModels.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Authentication\AuthenticationAPIClient.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Authentication\KeychainSessionStore.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Authentication\AuthenticationModel.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Authentication\AppleCredentialButton.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Authentication\AuthenticationViews.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Profile\MySettingsView.swift'),
    (Join-Path $iosRoot 'MoneySnap\VisualSystem\MoneySnapVisualSystem.swift'),
    (Join-Path $iosRoot 'MoneySnap\VisualSystem\MoneySnapTabBar.swift'),
    (Join-Path $iosRoot 'MoneySnap\Info.plist'),
    (Join-Path $iosRoot 'MoneySnap\Resources\Fonts\NotoSansKR-VariableFont_wght.ttf'),
    (Join-Path $iosRoot 'MoneySnap\Assets.xcassets\FoodSnap.imageset\food-snap.png'),
    (Join-Path $iosRoot 'MoneySnap\Assets.xcassets\CafeSnap.imageset\cafe-snap.png'),
    (Join-Path $iosRoot 'MoneySnapTests\AppShellTests.swift'),
    (Join-Path $iosRoot 'MoneySnapTests\TodaySnapViewModelTests.swift'),
    (Join-Path $iosRoot 'MoneySnapTests\AuthenticationModelTests.swift'),
    (Join-Path $iosRoot 'MoneySnapTests\AuthenticationAPIClientTests.swift')
    (Join-Path $iosRoot 'MoneySnapTests\AppleNonceTests.swift')
    (Join-Path $iosRoot 'MoneySnapTests\KeychainSessionStoreTests.swift')
    (Join-Path $iosRoot '..\contracts\examples\v1\identity\apple-credential-request.json')
    (Join-Path $iosRoot '..\contracts\examples\v1\identity\session-response.json')
    (Join-Path $iosRoot '..\contracts\examples\v1\identity\refresh-request.json')
    (Join-Path $iosRoot '..\contracts\examples\v1\identity\error-apple-reauthentication-rejected.json')
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
if ($project -notmatch 'ENABLE_TESTABILITY = YES;') {
    throw 'The Debug app target must support @testable integration tests.'
}
if ($project -notmatch 'path = \.\./\.\./contracts/examples/v1/identity;' -or
    $project -notmatch 'identity in Resources') {
    throw 'Canonical identity fixtures must be included in the MoneySnapTests resource phase.'
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
    'TodayCanvasLayout.swift',
    'TodaySnapCardViews.swift',
    'AuthenticationModels.swift',
    'AuthenticationAPIClient.swift',
    'KeychainSessionStore.swift',
    'AuthenticationModel.swift',
    'AppleCredentialButton.swift',
    'AuthenticationViews.swift',
    'MySettingsView.swift',
    'MoneySnapVisualSystem.swift',
    'MoneySnapTabBar.swift',
    'AppShellTests.swift',
    'TodaySnapViewModelTests.swift',
    'AuthenticationModelTests.swift',
    'AuthenticationAPIClientTests.swift'
    'AppleNonceTests.swift'
    'KeychainSessionStoreTests.swift'
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

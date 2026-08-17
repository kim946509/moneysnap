$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'validate-pbx-object-ids.ps1')

$iosRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$projectFile = Join-Path $iosRoot 'MoneySnap.xcodeproj\project.pbxproj'
$schemeFile = Join-Path $iosRoot 'MoneySnap.xcodeproj\xcshareddata\xcschemes\MoneySnap.xcscheme'
$requiredFiles = @(
    $projectFile,
    $schemeFile,
    (Join-Path $iosRoot 'scripts\validate-pbx-object-ids.ps1'),
    (Join-Path $iosRoot 'scripts\test-validate-pbx-object-ids.ps1'),
    (Join-Path $iosRoot 'scripts\test-validate-visual-baseline.ps1'),
    (Join-Path $iosRoot 'MoneySnap\App\MoneySnapApp.swift'),
    (Join-Path $iosRoot 'MoneySnap\App\VisualTestSupport.swift'),
    (Join-Path $iosRoot 'MoneySnap\App\AppShellView.swift'),
    (Join-Path $iosRoot 'MoneySnap\App\AppTab.swift'),
    (Join-Path $iosRoot 'MoneySnap\App\RouterPath.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Placeholder\PlaceholderView.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Home\TodaySnapModels.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Home\SnapJournalClient.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Home\TodaySnapViewModel.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Home\TodaySnapView.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Home\SnapDetailModel.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Home\SnapDetailView.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Home\TodayCanvasLayout.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Home\TodaySnapCardViews.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Capture\SnapRecordModels.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Capture\SnapCaptureModel.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Capture\SnapCaptureView.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Capture\JpegNormalizer.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Capture\PhotoQueueModel.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Capture\MediaClient.swift'),
    (Join-Path $iosRoot 'MoneySnap\MoneySnap.entitlements'),
    (Join-Path $iosRoot 'MoneySnapTests\JpegNormalizerTests.swift'),
    (Join-Path $iosRoot 'MoneySnapTests\MediaClientTests.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Authentication\AuthenticationModels.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Authentication\AuthenticationAPIClient.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Authentication\KeychainSessionStore.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Authentication\AuthenticationModel.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Authentication\AppleCredentialButton.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Authentication\AuthenticationViews.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Profile\MySettingsView.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Group\GroupModels.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Group\GroupListView.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Group\GroupDetailView.swift'),
    (Join-Path $iosRoot 'MoneySnap\Features\Archive\ArchiveView.swift'),
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
    (Join-Path $iosRoot 'MoneySnapTests\SnapCaptureModelTests.swift')
    (Join-Path $iosRoot 'MoneySnapTests\SnapJournalClientTests.swift')
    (Join-Path $iosRoot 'MoneySnapTests\AppleNonceTests.swift')
    (Join-Path $iosRoot 'MoneySnapTests\KeychainSessionStoreTests.swift')
    (Join-Path $iosRoot 'MoneySnapUITests\MoneySnapUITests.swift')
    (Join-Path $iosRoot '..\contracts\examples\v1\identity\apple-credential-request.json')
    (Join-Path $iosRoot '..\contracts\examples\v1\identity\session-response.json')
    (Join-Path $iosRoot '..\contracts\examples\v1\identity\refresh-request.json')
    (Join-Path $iosRoot '..\contracts\examples\v1\identity\error-apple-reauthentication-rejected.json')
    (Join-Path $iosRoot '..\contracts\examples\v1\snaps\record-request.json')
    (Join-Path $iosRoot '..\contracts\examples\v1\snaps\record-response.json')
    (Join-Path $iosRoot '..\contracts\examples\v1\snaps\today-response.json')
    (Join-Path $iosRoot '..\contracts\examples\v1\snaps\today-empty-response.json')
    (Join-Path $iosRoot '..\contracts\examples\v1\snaps\detail-response.json')
    (Join-Path $iosRoot '..\contracts\examples\v1\snaps\revise-request.json')
    (Join-Path $iosRoot '..\contracts\examples\v1\snaps\revise-response.json')
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
    $project -notmatch 'productType = "com\.apple\.product-type\.bundle\.unit-test";' -or
    $project -notmatch 'productType = "com\.apple\.product-type\.bundle\.ui-testing";') {
    throw 'Application, unit-test, or UI-testing target is missing.'
}
if ($project -match 'DEVELOPMENT_TEAM = [A-Z0-9]+;') {
    throw 'A signing team must not be committed before Apple setup.'
}
if ($project -notmatch 'ENABLE_TESTABILITY = YES;') {
    throw 'The Debug app target must support @testable integration tests.'
}
if ($project -notmatch 'CODE_SIGN_ENTITLEMENTS = MoneySnap/MoneySnap.entitlements;') {
    throw 'Sign in with Apple entitlements file is not attached to the app target.'
}
$entitlements = Get-Content -LiteralPath (Join-Path $iosRoot 'MoneySnap\MoneySnap.entitlements') -Raw
if ($entitlements -notmatch 'com\.apple\.developer\.applesignin') {
    throw 'MoneySnap.entitlements must enable Sign in with Apple.'
}
$infoPlist = Get-Content -LiteralPath (Join-Path $iosRoot 'MoneySnap\Info.plist') -Raw
if ($infoPlist -notmatch 'NSCameraUsageDescription' -or $infoPlist -notmatch 'NSPhotoLibraryUsageDescription') {
    throw 'Info.plist must declare camera and photo library usage for device capture.'
}
if ($project -notmatch 'path = \.\./\.\./contracts/examples/v1/identity;' -or
    $project -notmatch 'identity in Resources') {
    throw 'Canonical identity fixtures must be included in the MoneySnapTests resource phase.'
}
if ($project -notmatch 'path = \.\./\.\./contracts/examples/v1/snaps;' -or
    $project -notmatch 'snaps in Resources') {
    throw 'Canonical Snap fixtures must be included in the MoneySnapTests resource phase.'
}

Assert-PbxObjectIdentifiers -Project $project

$expectedSourceNames = @(
    'MoneySnapApp.swift',
    'VisualTestSupport.swift',
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
    'SnapRecordModels.swift',
    'SnapCaptureModel.swift',
    'SnapCaptureView.swift',
    'JpegNormalizer.swift',
    'PhotoQueueModel.swift',
    'MediaClient.swift',
    'SnapDetailView.swift',
    'GroupListView.swift',
    'ArchiveView.swift',
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
    'SnapCaptureModelTests.swift'
    'SnapJournalClientTests.swift'
    'JpegNormalizerTests.swift'
    'MediaClientTests.swift'
    'AppleNonceTests.swift'
    'KeychainSessionStoreTests.swift'
    'MoneySnapUITests.swift'
)
foreach ($sourceName in $expectedSourceNames) {
    if ($project -notmatch [regex]::Escape("path = $sourceName;")) {
        throw "PBX project does not reference $sourceName."
    }
}

if ($scheme.Scheme.BuildAction.BuildActionEntries.BuildActionEntry.Count -ne 3) {
    throw 'Shared scheme must build the app, unit-test, and UI-test targets.'
}
$testables = @($scheme.Scheme.TestAction.Testables.TestableReference)
if ($testables.Count -ne 2) {
    throw 'Shared scheme must run unit tests and UI tests.'
}
$uiTestable = $testables | Where-Object { $_.BuildableReference.BlueprintName -eq 'MoneySnapUITests' }
if (-not $uiTestable -or $uiTestable.parallelizable -ne 'NO') {
    throw 'MoneySnapUITests must be a non-parallel shared-scheme testable.'
}

$uiTargetConfigurations = [regex]::Matches(
    $project,
    '(?ms)/\* (?:Debug|Release) \*/ = \{\s*isa = XCBuildConfiguration;\s*buildSettings = \{(?<settings>.*?)\};\s*name = (?:Debug|Release);\s*\};'
) | Where-Object { $_.Groups['settings'].Value -match 'PRODUCT_BUNDLE_IDENTIFIER = com\.ansandy\.moneysnap\.uitests;' }
if ($uiTargetConfigurations.Count -ne 2) {
    throw 'MoneySnapUITests must have Debug and Release build configurations.'
}
foreach ($configuration in $uiTargetConfigurations) {
    $settings = $configuration.Groups['settings'].Value
    if ($settings -notmatch 'TEST_TARGET_NAME = MoneySnap;' -or $settings -match 'TEST_HOST|BUNDLE_LOADER') {
        throw 'MoneySnapUITests must use TEST_TARGET_NAME without app-hosted unit-test settings.'
    }
}

$visualSupport = Get-Content -Raw -LiteralPath (Join-Path $iosRoot 'MoneySnap\App\VisualTestSupport.swift')
if ($visualSupport -notmatch '(?s)^#if DEBUG\s+.*VisualScenario.*case home.*case my.*case invalid.*#endif\s*$') {
    throw 'Visual test parser, allowlist, fixtures, and fail-closed path must share one DEBUG-only support boundary.'
}
if ($visualSupport -notmatch 'struct\s+InMemorySnapJournalClient\s*:\s*SnapJournalClient') {
    throw 'The DEBUG support boundary must contain the visual SnapJournalClient adapter.'
}
$snapJournal = Get-Content -Raw -LiteralPath (Join-Path $iosRoot 'MoneySnap\Features\Home\SnapJournalClient.swift')
if ($snapJournal -match 'figmaHome|fixture|InMemorySnapJournalClient') {
    throw 'Production SnapJournalClient source must not contain visual fixtures.'
}
$snapModels = Get-Content -Raw -LiteralPath (Join-Path $iosRoot 'MoneySnap\Features\Home\TodaySnapModels.swift')
if ($snapModels -match 'figmaReference|fixture') {
    throw 'Production Snap model source must not contain visual fixture values.'
}
$appShell = Get-Content -Raw -LiteralPath (Join-Path $iosRoot 'MoneySnap\App\AppShellView.swift')
if ($appShell -match 'snapJournalClient:\s*any\s+SnapJournalClient\s*=') {
    throw 'AppShellView must require an explicit SnapJournalClient adapter.'
}
$appEntry = Get-Content -Raw -LiteralPath (Join-Path $iosRoot 'MoneySnap\App\MoneySnapApp.swift')
if ($appEntry -notmatch 'case\s+(?:let\s+)?\.invalid' -or $appEntry -notmatch 'VisualLaunchFailureView') {
    throw 'Unknown non-empty visual scenarios must fail closed before live app wiring.'
}
$appShellTests = Get-Content -Raw -LiteralPath (Join-Path $iosRoot 'MoneySnapTests\AppShellTests.swift')
if ($appShellTests -notmatch '@testable\s+import\s+MoneySnap') {
    throw 'App shell tests must use testable import for internal DEBUG support.'
}
$uiTests = Get-Content -Raw -LiteralPath (Join-Path $iosRoot 'MoneySnapUITests\MoneySnapUITests.swift')
if ([regex]::Matches($uiTests, '@MainActor').Count -lt 3) {
    throw 'XCUITest methods and their element helper must stay on the main actor.'
}
if ($assets.info.author -ne 'xcode' -or $assets.info.version -ne 1) {
    throw 'Asset catalog metadata is invalid.'
}

$infoPlist = [xml](Get-Content -LiteralPath (Join-Path $iosRoot 'MoneySnap\Info.plist') -Raw)
if ($infoPlist.plist.dict.array.string -notcontains 'NotoSansKR-VariableFont_wght.ttf') {
    throw 'Noto Sans KR must be registered in UIAppFonts.'
}

$powerShellPath = (Get-Process -Id $PID).Path
foreach ($regressionProbe in @(
    (Join-Path $iosRoot 'scripts\test-validate-pbx-object-ids.ps1'),
    (Join-Path $iosRoot 'scripts\test-validate-visual-baseline.ps1')
)) {
    & $powerShellPath -NoProfile -ExecutionPolicy Bypass -File $regressionProbe
    if ($LASTEXITCODE -ne 0) {
        throw "iOS validator regression probe failed: $regressionProbe"
    }
}

Write-Output 'MoneySnap iOS project static validation: OK'

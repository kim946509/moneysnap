[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Require-File {
    param([Parameter(Mandatory)][string]$RelativePath)

    $path = Join-Path $repositoryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required CI/CD file is missing: $RelativePath"
    }

    return $path
}

function Require-Match {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Description
    )

    if ($Content -notmatch $Pattern) {
        throw "CI/CD contract is missing: $Description"
    }
}

function Require-FullActionShaPins {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Description
    )

    $references = [regex]::Matches($Content, '(?m)^\s*uses:\s*([^\s#]+)')
    foreach ($reference in $references) {
        $value = $reference.Groups[1].Value
        if ($value.StartsWith('./')) {
            continue
        }
        if ($value -notmatch '^[^@]+@[0-9a-f]{40}$') {
            throw "$Description action is not pinned to a full commit SHA: $value"
        }
    }
}

$workflowPath = Require-File '.github/workflows/server-ci-cd.yml'
$iosWorkflowPath = Require-File '.github/workflows/ios-ci.yml'
$iosTestPath = Require-File 'ios/scripts/test.sh'
$deployPath = Require-File 'server/scripts/deploy.ps1'
$deploymentModulePath = Require-File 'server/scripts/MoneySnap.Deployment.psm1'
$deploymentTestPath = Require-File 'server/scripts/test-deployment-support.ps1'
$runPath = Require-File 'server/scripts/run-server.ps1'
$hostPath = Require-File 'infra/windows/install-server-host.ps1'
$xcodeHookPath = Require-File 'ios/ci_scripts/ci_post_clone.sh'
$dependabotPath = Require-File '.github/dependabot.yml'

$workflow = Get-Content -LiteralPath $workflowPath -Raw
Require-Match $workflow '(?m)^\s*pull_request:\s*$' 'pull request trigger'
Require-Match $workflow '(?ms)^\s*push:\s*.*?branches:\s*\[main\]' 'main push trigger'
if ([regex]::Matches($workflow, 'contracts\/\*\*').Count -lt 2) {
    throw 'Server CI/CD contract is missing contracts/** in pull request and main push paths'
}
Require-Match $workflow '(?ms)^permissions:\s*\r?\n\s*contents:\s*read\s*$' 'read-only workflow permissions'
Require-Match $workflow '(?m)^\s*concurrency:\s*$' 'deployment concurrency'
Require-Match $workflow 'runs-on:\s*ubuntu-latest' 'GitHub-hosted server build runner'
Require-Match $workflow '\.\/gradlew\s+test\s+bootJar' 'server test and bootJar command'
Require-Match $workflow 'actions\/upload-artifact@[0-9a-f]{40}' 'SHA-pinned immutable JAR artifact upload'
Require-Match $workflow 'sha256sum\s+build\/libs\/moneysnap-server\.jar' 'JAR checksum manifest creation'
Require-Match $workflow 'environment:\s*server-development' 'protected development environment'
Require-Match $workflow 'runs-on:\s*\[self-hosted,\s*Windows,\s*X64,\s*moneysnap-dev\]' 'dedicated Windows deployment runner'
Require-Match $workflow 'runs-on:\s*windows-latest' 'Windows deployment behavior test runner'
Require-Match $workflow '\.\/server\/scripts\/test-deployment-support\.ps1' 'Windows deployment behavior test command'
Require-Match $workflow 'needs:\s*\[build,\s*deployment-script-test\]' 'deployment dependency on build and Windows behavior tests'
Require-Match $workflow "github\.event_name\s*==\s*'push'.*github\.ref\s*==\s*'refs\/heads\/main'" 'main-only deployment condition'
Require-Match $workflow 'actions\/download-artifact@[0-9a-f]{40}' 'SHA-pinned deployment artifact download'
Require-Match $workflow '-ChecksumPath' 'deployment checksum verification input'
foreach ($secretName in @(
    'NEON_RUNTIME_DATABASE_URL',
    'NEON_RUNTIME_DATABASE_USERNAME',
    'NEON_RUNTIME_DATABASE_PASSWORD',
    'NEON_MIGRATION_DATABASE_URL',
    'NEON_MIGRATION_DATABASE_USERNAME',
    'NEON_MIGRATION_DATABASE_PASSWORD'
)) {
    Require-Match `
        $workflow `
        ("{0}:\s*\$\{{\{{\s*secrets\.{0}\s*\}}\}}" -f $secretName) `
        "$secretName environment secret"
}
Require-FullActionShaPins -Content $workflow -Description 'Server workflow'

$iosWorkflow = Get-Content -LiteralPath $iosWorkflowPath -Raw
Require-Match $iosWorkflow 'runs-on:\s*macos-15' 'pinned GitHub-hosted macOS runner image'
Require-Match $iosWorkflow 'bash\s+ios\/scripts\/test\.sh' 'native Swift test command'
Require-Match $iosWorkflow 'RESULT_BUNDLE_PATH' 'failed test result bundle contract'
Require-Match $iosWorkflow 'if:\s*failure\(\)' 'failure-only diagnostics upload'
Require-FullActionShaPins -Content $iosWorkflow -Description 'iOS workflow'

$iosTest = Get-Content -LiteralPath $iosTestPath -Raw
Require-Match $iosTest 'CODE_SIGNING_ALLOWED=NO' 'signing-free iOS test command'
Require-Match $iosTest 'RESULT_BUNDLE_PATH' 'optional iOS result bundle output'

$deploy = Get-Content -LiteralPath $deployPath -Raw
Require-Match $deploy 'function\s+Wait-ForHealthyServer' 'health deployment gate'
Require-Match $deploy 'Invoke-MoneySnapDeploymentOrchestration' 'tested deployment orchestration'
Require-Match $deploy 'Assert-MoneySnapArtifactChecksum' 'tested artifact checksum enforcement'
Require-Match $deploy 'Assert-MoneySnapHealthResponse' 'UP and health detail assertion'

$deploymentModule = Get-Content -LiteralPath $deploymentModulePath -Raw
Require-Match $deploymentModule 'Protect-MoneySnapSecretDirectory[\s\S]*WriteAllText' 'ACL protection before secret writes'
Require-Match $deploymentModule 'Restore-MoneySnapPreviousReleaseFiles' 'rollback file restoration boundary'
Require-Match $deploymentModule 'previousRunner' 'previous runner script rollback'
Require-Match $deploymentModule 'Invoke-MoneySnapDeploymentOrchestration' 'deployment orchestration boundary'
Require-Match $deploymentModule 'Assert-MoneySnapHealthResponse' 'health response boundary'

$deploymentTest = Get-Content -LiteralPath $deploymentTestPath -Raw
Require-Match $deploymentTest 'tampered artifact was not rejected' 'checksum rejection behavior test'
Require-Match $deploymentTest 'secret directory still inherits ACL entries' 'secret ACL behavior test'
Require-Match $deploymentTest 'rollback did not restore the previous runner script' 'rollback behavior test'
Require-Match $deploymentTest 'healthy deployment orchestration order is invalid' 'post-health state commit ordering test'
Require-Match $deploymentTest 'unhealthy deployment did not rollback before state commit' 'failed-health rollback ordering test'
Require-Match $deploymentTest 'component-exposing health response was not rejected' 'health details rejection test'

$runServer = Get-Content -LiteralPath $runPath -Raw
Require-Match $runServer 'NEON_RUNTIME_DATABASE_URL' 'runtime secret loading'
Require-Match $runServer 'NEON_MIGRATION_DATABASE_URL' 'migration secret loading'
Require-Match $runServer 'java-path\.txt' 'bootstrap-persisted Java executable'
Require-Match $runServer '&\s*\$javaPath\s+-jar' 'foreground Java process for task supervision'

$hostInstall = Get-Content -LiteralPath $hostPath -Raw
Require-Match $hostInstall 'Register-ScheduledTask' 'Windows scheduled task registration'
Require-Match $hostInstall "S-1-5-18" 'LocalSystem task principal'
Require-Match $hostInstall 'moneysnap-dev' 'dedicated runner label contract'
Require-Match $hostInstall '\(\?:openjdk\|java\)' 'OpenJDK and Java 21 version acceptance'
Require-Match $hostInstall 'java-path\.txt' 'absolute Java path persistence'

$xcodeHook = Get-Content -LiteralPath $xcodeHookPath -Raw
Require-Match $xcodeHook '^#!\/bin\/sh' 'portable Xcode Cloud shell hook'
Require-Match $xcodeHook 'xcodebuild -version' 'Xcode toolchain evidence'
Require-Match $xcodeHook 'MoneySnap\.xcodeproj' 'Money Snap project validation'

$dependabot = Get-Content -LiteralPath $dependabotPath -Raw
Require-Match $dependabot 'package-ecosystem:\s*"github-actions"' 'GitHub Actions dependency updates'

Write-Output 'Money Snap CI/CD static contract: OK'

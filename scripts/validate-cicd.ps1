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
$dockerfilePath = Require-File 'server/Dockerfile'
$composePath = Require-File 'infra/ubuntu/compose.yaml'
$deployPath = Require-File 'infra/ubuntu/deploy.sh'
$prometheusJobPath = Require-File 'infra/ubuntu/prometheus-moneysnap-job.yaml'
$deploymentTestPath = Require-File 'server/scripts/test-docker-deployment.sh'
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
Require-Match $workflow 'docker\s+build' 'Docker image build'
Require-Match $workflow 'docker\s+save' 'immutable Docker image archive'
Require-Match $workflow 'actions\/upload-artifact@[0-9a-f]{40}' 'SHA-pinned immutable image artifact upload'
Require-Match $workflow 'sha256sum\s+moneysnap-server\.tar\.gz' 'Docker image archive checksum manifest creation'
Require-Match $workflow 'environment:\s*server-development' 'protected development environment'
Require-Match $workflow 'bash\s+server\/scripts\/test-docker-deployment\.sh' 'Ubuntu Docker deployment behavior test command'
Require-Match $workflow 'needs:\s*build' 'deployment dependency on tested image build'
Require-Match $workflow "github\.event_name\s*==\s*'push'.*github\.ref\s*==\s*'refs\/heads\/main'" 'main-only deployment condition'
Require-Match $workflow 'actions\/download-artifact@[0-9a-f]{40}' 'SHA-pinned deployment artifact download'
Require-Match $workflow 'scp\s+' 'SSH artifact transfer'
Require-Match $workflow 'ssh\s+' 'Ubuntu remote deployment command'
if ($workflow -match 'self-hosted|Windows|moneysnap-dev') {
    throw 'Server workflow still contains the retired Windows self-hosted deployment path'
}
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
foreach ($secretName in @(
    'SERVER_HOST',
    'SERVER_SSH_PORT',
    'SERVER_SSH_USER',
    'SERVER_SSH_PRIVATE_KEY',
    'SERVER_SSH_KNOWN_HOSTS'
)) {
    Require-Match `
        $workflow `
        ("secrets\.{0}" -f $secretName) `
        "$secretName deployment secret"
}
Require-FullActionShaPins -Content $workflow -Description 'Server workflow'

$iosWorkflow = Get-Content -LiteralPath $iosWorkflowPath -Raw
Require-Match $iosWorkflow 'runs-on:\s*macos-15' 'pinned GitHub-hosted macOS runner image'
Require-Match $iosWorkflow 'bash\s+ios\/scripts\/test\.sh' 'native Swift test command'
Require-Match $iosWorkflow 'RESULT_BUNDLE_PATH' 'failed test result bundle contract'
Require-Match $iosWorkflow 'if:\s*failure\(\)' 'failure-only diagnostics upload'
Require-FullActionShaPins -Content $iosWorkflow -Description 'iOS workflow'

$iosTest = Get-Content -LiteralPath $iosTestPath -Raw
$unsignedNativeTestOverride = '(?i)\bCODE_SIGNING_ALLOWED\s*(?:=|:)\s*["'']?NO["'']?\b'
if ($iosTest -match $unsignedNativeTestOverride -or $iosWorkflow -match $unsignedNativeTestOverride) {
    throw 'Native iOS tests must keep Xcode Simulator ad-hoc signing enabled for Keychain entitlements'
}
Require-Match $iosTest 'RESULT_BUNDLE_PATH' 'optional iOS result bundle output'

$dockerfile = Get-Content -LiteralPath $dockerfilePath -Raw
Require-Match $dockerfile '^FROM\s+[^\s]+@sha256:[0-9a-f]{64}' 'digest-pinned Java runtime image'
Require-Match $dockerfile '(?m)^USER\s+[^0\s]+' 'non-root container user'
Require-Match $dockerfile 'HEALTHCHECK' 'container healthcheck'

$compose = Get-Content -LiteralPath $composePath -Raw
Require-Match $compose '192\.168\.1\.102:9090:8080' 'private host 9090 to application 8080 mapping'
Require-Match $compose 'name:\s*main' 'existing monitoring network attachment'
Require-Match $compose 'MANAGEMENT_SERVER_PORT:\s*"9091"' 'container-only management port'
Require-Match $compose 'restart:\s*unless-stopped' 'restart policy'

$deploy = Get-Content -LiteralPath $deployPath -Raw
Require-Match $deploy 'sha256sum\s+--check' 'image archive checksum verification'
Require-Match $deploy '\$docker_bin"\s+load' 'Docker image load'
Require-Match $deploy 'previous_image' 'previous image rollback boundary'
Require-Match $deploy '\$docker_bin"\s+compose' 'Compose deployment'

$deploymentTest = Get-Content -LiteralPath $deploymentTestPath -Raw
Require-Match $deploymentTest 'healthy deployment' 'healthy deployment behavior test'
Require-Match $deploymentTest 'rollback' 'failed health rollback behavior test'
Require-Match $deploymentTest 'PREVIOUS_SECRET=preserved' 'same-release secret restoration behavior test'

$prometheusJob = Get-Content -LiteralPath $prometheusJobPath -Raw
Require-Match $prometheusJob 'job_name:\s*moneysnap_server' 'Money Snap Prometheus job'
Require-Match $prometheusJob 'moneysnap-server:9091' 'container-only Money Snap metrics target'

$xcodeHook = Get-Content -LiteralPath $xcodeHookPath -Raw
Require-Match $xcodeHook '^#!\/bin\/sh' 'portable Xcode Cloud shell hook'
Require-Match $xcodeHook 'xcodebuild -version' 'Xcode toolchain evidence'
Require-Match $xcodeHook 'MoneySnap\.xcodeproj' 'Money Snap project validation'

$dependabot = Get-Content -LiteralPath $dependabotPath -Raw
Require-Match $dependabot 'package-ecosystem:\s*"github-actions"' 'GitHub Actions dependency updates'

Write-Output 'Money Snap CI/CD static contract: OK'

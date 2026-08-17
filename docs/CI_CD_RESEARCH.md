# Money Snap CI/CD 공식 조사와 권장 설계

> 역사적 조사: Windows self-hosted runner와 named Tunnel 후보를 검토한 기록이다. 2026-08-09 이후 현재 실행 계약은 Ubuntu Docker/SSH 방식의 `docs/CI_CD.md`와 ADR-003·ADR-008을 따른다.

> 상태: implementation input
>
> 조사 기준일: 2026-08-08
>
> 범위: GitHub Actions, GitHub-hosted macOS/Xcode, Xcode Cloud/TestFlight, Windows origin 뒤 Cloudflare named Tunnel
> 출처 정책: GitHub, Gradle, Apple, Cloudflare의 공식 문서와 공식 저장소만 사용했다.

## 결론

Money Snap에는 한 서비스에 모든 책임을 몰아넣기보다 다음 네 lane을 두는 편이 맞다.

| Lane | 실행 위치 | 책임 | 장기 비밀값 |
|---|---|---|---|
| Backend CI | GitHub-hosted Ubuntu | Java 21 설정, Gradle test, `bootJar`, checksum, JAR artifact | 없음 |
| Backend CD | 전용 Windows self-hosted runner | 같은 run의 검증된 JAR 설치, Spring Boot origin 재시작, loopback health check, 실패 시 JAR rollback | GitHub가 아니라 origin host의 로컬 secret store |
| iOS CI | GitHub-hosted `macos-15` | Apple credential·provisioning 없는 Simulator build/test(Xcode ad-hoc 서명)와 result bundle 수집 | 없음 |
| iOS CD | Xcode Cloud | Apple-managed build/sign/archive, TestFlight 배포 | repository나 GitHub Actions에 Apple signing private key를 두지 않음 |

이 역할 분리는 다음 공식 사실에 근거한다.

- Xcode Cloud는 build, test, analyze, archive와 TestFlight post-action을 제공하고, Apple Developer Program에는 월 25 compute hours가 포함된다. 최초 workflow는 Xcode에서 만들어야 하며 이후 Xcode 또는 App Store Connect에서 관리할 수 있다. [Apple Xcode Cloud](https://developer.apple.com/xcode-cloud/), [첫 workflow 구성](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow), [workflow reference](https://developer.apple.com/documentation/xcode/xcode-cloud-workflow-reference)
- Windows의 `cloudflared`는 system service로 설치할 수 있고, remotely-managed tunnel은 실행에 tunnel token 하나만 필요하다. 이 token을 가진 사람은 누구나 connector를 실행할 수 있으므로 배포 artifact와 같은 저장소 자산으로 취급하면 안 된다. [Cloudflare Tunnel setup](https://developers.cloudflare.com/tunnel/setup/), [tunnel tokens](https://developers.cloudflare.com/tunnel/advanced/tunnel-tokens/)
- self-hosted runner는 매 job마다 폐기되는 격리 VM이 아니며 지속적으로 침해될 수 있다. 따라서 PR 코드를 origin host에서 실행하지 않고, 배포 job만 전용 runner에 라우팅해야 한다. [GitHub Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use), [self-hosted runners reference](https://docs.github.com/en/actions/reference/runners/self-hosted-runners)

## 1. GitHub Actions: Java와 Gradle

### 권장 action과 고정 방식

2026-08-08에 공식 GitHub API로 확인한 최신 major tag와 tag가 가리키는 commit은 다음과 같다. 실제 workflow에서는 사람이 읽기 쉬운 tag를 `uses:`에 쓰지 않고 아래 전체 commit SHA를 쓰며, 옆 주석에 major 또는 release tag를 기록한다. GitHub는 full-length commit SHA가 action을 immutable release로 사용하는 유일한 방법이라고 명시한다. [GitHub Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)

| 목적 | 확인한 major | workflow에 고정할 commit |
|---|---|---|
| checkout | `actions/checkout@v7` | [`3d3c42e5aac5ba805825da76410c181273ba90b1`](https://github.com/actions/checkout/commit/3d3c42e5aac5ba805825da76410c181273ba90b1) |
| Java toolchain | `actions/setup-java@v5` | [`b6effb05e454b25005698d916606bdc6ffcbf961`](https://github.com/actions/setup-java/commit/b6effb05e454b25005698d916606bdc6ffcbf961) |
| Gradle setup/cache/wrapper validation | `gradle/actions/setup-gradle@v6` | [`9c971963bec38e04b3d30dcc455b5382be2fdbfb`](https://github.com/gradle/actions/commit/9c971963bec38e04b3d30dcc455b5382be2fdbfb) |
| artifact upload | `actions/upload-artifact@v7` | [`043fb46d1a93c77aae656e7c1c64a875d1fc6a0a`](https://github.com/actions/upload-artifact/commit/043fb46d1a93c77aae656e7c1c64a875d1fc6a0a) |
| artifact download | `actions/download-artifact@v8` | [`3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c`](https://github.com/actions/download-artifact/commit/3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c) |
| provenance attestation | `actions/attest@v4` | [`1e69f48acb82d1966a394da916b4c1698aa569d6`](https://github.com/actions/attest/commit/1e69f48acb82d1966a394da916b4c1698aa569d6) |

Gradle 공식 action인 `setup-gradle`은 Gradle User Home의 distribution, resolved dependency, local build cache를 자동 저장·복원하고 Gradle Wrapper를 검증한다. Money Snap은 `setup-java`에는 Java 21/Temurin 선택만 맡기고 Gradle cache는 `setup-gradle` 하나만 소유하게 해야 중복 cache를 피할 수 있다. [Gradle on GitHub Actions](https://docs.gradle.org/current/userguide/github-actions.html), [GitHub Java with Gradle](https://docs.github.com/en/actions/tutorials/build-and-test-code/java-with-gradle)

`gradle/actions/dependency-submission`은 resolved dependency graph를 GitHub에 제출해 Dependency graph와 Dependabot alerts의 입력으로 쓸 수 있다. 이 job은 PR마다 실행하지 않고 기본 branch push에서만 실행하며, 해당 job에만 `contents: write`를 부여한다. 다른 CI job의 기본 권한은 `contents: read`다. [Gradle on GitHub Actions](https://docs.gradle.org/current/userguide/github-actions.html)

### cache, artifact, provenance의 구분

- cache는 다음 build가 다시 사용할 dependency/build state용이고, artifact는 run 종료 뒤 보관하거나 job 사이에 전달할 JAR, test report, result bundle용이다. [GitHub dependency caching](https://docs.github.com/en/actions/concepts/workflows-and-actions/dependency-caching), [workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts)
- PR run은 기본 branch의 cache를 복원할 수 있다. 따라서 fork 또는 신뢰하지 않는 branch에서 self-hosted deployment runner나 production secret을 사용하지 않는다. [GitHub dependency caching reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching), [GitHub Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)
- artifact attestation은 build provenance를 commit, workflow, repository, environment와 연결하지만 artifact 자체가 안전하다는 보증은 아니다. [GitHub artifact attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations)
- repository는 public으로 전환되어 artifact attestation을 사용할 수 있다. 다만 현재 개발 JAR은 public release artifact가 아니므로 기본 workflow에는 추가하지 않고, 공개 release provenance가 필요해질 때 release JAR에만 `actions/attest`를 추가한다. [GitHub artifact attestation availability](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)

### environment와 concurrency

GitHub environment는 branch 제한, required reviewer, secret 접근 지연을 제공한다. job은 protection rule을 통과한 뒤에만 environment secret에 접근한다. public repository에서는 무료 플랜도 protection rule을 사용할 수 있지만 현재 `server-development`는 custom branch policy로 `main`만 허용하고 required reviewer는 아직 구성하지 않았다. [GitHub deployment environments](https://docs.github.com/en/actions/concepts/workflows-and-actions/deployment-environments), [deployments and environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)

따라서 무료 private 단계에서는 다음 경계를 사용한다.

- CI는 PR과 branch push에서 자동 실행한다.
- dev 배포는 `main`의 성공한 build에 한해 자동화할 수 있다.
- production 또는 외부 노출 배포는 `workflow_dispatch`와 branch protection으로 명시적 실행을 요구한다. 유료 environment protection을 사용할 수 있게 되면 required reviewer와 prevent self-review를 추가한다.
- CI concurrency는 같은 branch의 오래된 run을 `cancel-in-progress: true`로 취소한다.
- deployment concurrency는 환경별 하나의 group을 두고 `cancel-in-progress: false`로 실행 중 배포를 중단하지 않는다. GitHub concurrency group은 기본적으로 같은 group의 동시 실행을 제한한다. [GitHub concurrency](https://docs.github.com/en/actions/concepts/workflows-and-actions/concurrency), [workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)

## 2. GitHub-hosted macOS에서 iOS build/test

standard Apple Silicon label은 `macos-latest`, `macos-14`, `macos-15`, `macos-26`이고 Intel label은 `macos-15-intel`, `macos-26-intel`이다. `-latest`는 GitHub가 제공하는 최신 stable image일 뿐 운영체제 공급자의 최신 버전과 같다는 보장이 없으므로 Money Snap은 `macos-latest` 대신 `macos-15`를 명시한다. [GitHub-hosted runners reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

runner image는 지원하는 Xcode와 Simulator runtime을 계속 갱신한다. 공식 runner-images 정책상 macOS image당 지원 Xcode major와 platform tool/runtime 범위가 제한되고, 새 patch가 나오면 이전 patch가 교체될 수 있다. 따라서 설치돼 있다고 가정한 특정 simulator UDID를 workflow에 하드코딩하면 안 된다. run 시작 시 `xcodebuild -version`, `xcrun simctl list devices available`을 evidence로 남기고, repository의 `ios/scripts/test.sh`처럼 available destination을 발견해 test해야 한다. [GitHub runner-images](https://github.com/actions/runner-images), [macOS 15 installed software](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md)

Apple Silicon macOS runner에는 static UDID가 없고 nested virtualization도 지원하지 않는다. 이 lane은 iOS Simulator build/test에만 쓰며 development provisioning profile로 실제 device에 설치하는 용도로 사용하지 않는다. Apple credential·provisioning 없이 Xcode 기본 ad-hoc(`Sign to Run Locally`) 서명으로 `xcodebuild test`가 성공하는지를 CI gate로 삼는다. [GitHub-hosted macOS limitations](https://docs.github.com/en/actions/reference/runners/github-hosted-runners#limitations-for-arm64-macos-runners)

public repository의 standard GitHub-hosted runner 사용은 무료다. 그래도 실행 시간과 피드백 지연을 줄이기 위해 `ios/**` 또는 shared contract가 바뀐 PR/main에서만 native lane을 실행하고, 문서-only 변경에는 실행하지 않는다. [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)

권장 iOS CI job은 다음만 수행한다.

1. full SHA로 checkout한다.
2. `xcodebuild -version`과 available Simulator를 기록한다.
3. `bash ios/scripts/test.sh`를 실행한다.
4. 실패했을 때만 `.xcresult`와 진단 log를 짧은 retention의 artifact로 업로드한다.
5. certificate, provisioning profile, App Store Connect key를 주입하지 않는다.

## 3. TestFlight: Xcode Cloud와 GitHub Actions 역할 분리

### 현재 선택: Xcode Cloud가 CD를 소유한다

Xcode Cloud의 archive action은 TestFlight 배포에 필수이고, deployment preparation을 internal TestFlight 또는 TestFlight+App Store로 나눌 수 있다. post-action은 archive를 TestFlight tester에게 배포할 수 있다. [Xcode Cloud actions](https://developer.apple.com/documentation/xcode/configuring-your-xcode-cloud-workflow-s-actions), [distribution workflow](https://developer.apple.com/documentation/xcode/creating-a-workflow-that-builds-your-app-for-distribution)

최초 설정에는 다음 사람이 수행하는 Apple 측 작업이 필요하다.

1. 최종 Bundle ID와 Team을 Xcode에서 확정한다.
2. App Store Connect app record를 만든다. Xcode Cloud로 app을 build/distribute하려면 app record가 필요하다.
3. Xcode에서 source repository 접근을 승인하고 첫 Xcode Cloud workflow/build를 시작한다.
4. 첫 성공 뒤 App Store Connect에서 workflow start condition, test destination, archive와 TestFlight post-action을 조정한다. [첫 Xcode Cloud workflow](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow), [App Store Connect workflow](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow)

Xcode 13+의 Organizer distribution workflow는 로컬 distribution certificate가 없으면 cloud-managed certificate로 서명할 수 있고, Xcode는 cloud-managed certificate를 team과 자동 공유한다. 따라서 Apple 통합 lane인 Xcode Cloud를 TestFlight CD로 선택하면 GitHub repository에 `.p12`, certificate password, provisioning profile을 저장할 이유가 없다. 이는 Apple의 cloud signing과 Xcode Cloud 통합에서 도출한 설계 결론이다. [Apple cloud-managed certificates](https://developer.apple.com/help/account/certificates/cloud-managed-certificates/), [signing identities](https://developer.apple.com/documentation/xcode/sharing-your-teams-signing-certificates)

### App Store Connect API key가 필요한 경우

Xcode Cloud UI/workflow의 기본 TestFlight post-action에는 별도의 GitHub-held API key를 추가하지 않는다. App Store Connect API로 tester/group 관리, build 상태 조회, artifact 다운로드 또는 workflow 시작을 추가 자동화할 때만 key를 만든다. API 요청은 JWT가 필요하며 API key의 private half로 서명한다. team key는 역할 수준은 다르더라도 모든 app에 접근할 수 있고 individual key는 해당 사용자의 app/permission 범위에 묶이므로, Money Snap 하나만 자동화할 때는 필요한 권한만 가진 individual key가 더 좁은 선택이다. [App Store Connect API keys](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api), [App Store Connect API](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api)

private key는 한 번만 다운로드할 수 있고 Apple은 사본을 보관하지 않는다. repository, client code, log, artifact에 넣지 않으며 분실·노출 시 즉시 revoke한다. API 자동화를 추가한다면 secret 경계는 `AuthKey_<KEY_ID>.p8`, Key ID, team key일 때 Issuer ID이며, workflow에는 최소 역할만 제공한다. [Apple API key storage](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api), [revoking API keys](https://developer.apple.com/documentation/appstoreconnectapi/revoking-api-keys)

GitHub Actions에서 직접 TestFlight upload를 구현하는 대안은 distribution signing identity/profile과 App Store Connect JWT key 보관·rotation을 GitHub 쪽에 다시 만들게 된다. Apple은 Xcode, Transporter, altool 또는 App Store Connect API/JWT로 build를 upload할 수 있다고 설명하지만, 현재 프로젝트에는 이 중복 credential surface보다 Xcode Cloud가 단순하고 포함된 25시간을 활용할 수 있다. [Apple upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/), [Apple Xcode Cloud](https://developer.apple.com/xcode-cloud/)

## 4. Windows Spring Boot origin과 Cloudflare named Tunnel

### CD가 관리할 것

Backend CD는 Cloudflare tunnel object를 매 release마다 만들거나 token을 회전하지 않는다. application release와 tunnel lifecycle을 분리한다.

- CI에서 만든 동일 JAR과 SHA-256 manifest를 Windows origin으로 전달하고 새 release directory에 둔다.
- 현재 JAR을 rollback 후보로 보존한 뒤 Spring Boot application service만 재시작한다.
- `http://127.0.0.1:8080/actuator/health`가 제한 시간 안에 `UP`인지 검사한다.
- 실패하면 이전 JAR로 application service를 되돌리고 loopback health를 다시 검사한다.
- public hostname이 승인·생성된 뒤에는 공개된 비-Actuator probe도 확인하되 `/actuator/**`는 외부에서 404/차단되는지 별도 검증한다.
- DB migration은 down migration으로 자동 rollback하지 않는다. 이전 JAR과 호환되는 expand-first schema 변경만 자동 JAR rollback 대상으로 삼는다.

Tunnel은 origin port를 외부에 열지 않고 `cloudflared`가 Cloudflare로 outbound connection을 만든다. Cloudflare는 ingress를 차단하고 tunnel에 선언한 service만 노출하는 positive security model을 권장한다. `cloudflared`와 Spring Boot는 서로 다른 Windows service로 유지해 application release가 tunnel process를 불필요하게 재시작하지 않도록 한다. [Cloudflare Tunnel configuration](https://developers.cloudflare.com/tunnel/configuration/), [run as a service](https://developers.cloudflare.com/tunnel/advanced/local-management/as-a-service/)

### 최초 provisioning과 변경 책임

Cloudflare는 대부분의 경우 remotely-managed tunnel을 권장한다. 설정을 Cloudflare에 저장해 Dashboard/API/Terraform에서 관리할 수 있기 때문이다. Money Snap도 dev/prod별 remotely-managed named tunnel을 사용하고 Windows origin에는 replica만 설치한다. [Cloudflare remotely-managed recommendation](https://developers.cloudflare.com/tunnel/advanced/local-management/), [Cloudflare Tunnel setup](https://developers.cloudflare.com/tunnel/setup/)

다음 작업은 application CD가 아니라 승인된 infrastructure workflow 또는 수동 provisioning이 소유한다.

- tunnel 생성·삭제
- public hostname과 DNS CNAME 생성·변경
- `/actuator/**` 외부 차단을 포함한 ingress/public hostname rule 변경
- tunnel token 발급·rotation
- `cloudflared` binary update와 Windows service 재설치

Tunnel과 DNS를 API로 만들 때 공식 setup에 필요한 권한은 account의 Cloudflare Tunnel Edit와 대상 zone의 DNS Edit다. token은 해당 account/zone으로 resource scope를 제한하고, runtime tunnel token과 같은 값으로 재사용하지 않는다. Cloudflare API token secret도 한 번만 표시되며 승인된 resource에 대해 부여된 동작을 수행할 수 있으므로 plaintext 저장을 금지한다. [Cloudflare Tunnel API permissions](https://developers.cloudflare.com/tunnel/setup/), [create API token](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/), [API token permissions](https://developers.cloudflare.com/fundamentals/api/reference/permissions/)

### secret 경계

| Secret | 보관 위치 | 접근 주체 | 금지 사항 |
|---|---|---|---|
| Neon runtime pooled URL/user/password | Windows origin local secret store | Spring Boot application service account | GitHub-hosted CI, iOS, artifact에 주입 금지 |
| Neon migration direct URL/owner | Windows origin의 migration 전용 secret | 승인된 deploy/migration process만 | 평상시 runtime process에 상시 제공하지 않음 |
| R2 bucket-scoped access key/secret | Windows origin local secret store | Spring Boot media adapter | iOS, repository, GitHub-hosted CI 금지 |
| Cloudflare tunnel token | Windows host의 ACL 제한 token file | `cloudflared` service account | application service, JAR, GitHub artifact 금지 |
| Cloudflare management API token | 승인된 infrastructure secret store | tunnel/DNS provisioning workflow만 | `cloudflared` runtime token으로 재사용 금지 |
| App Store Connect `.p8` | Xcode Cloud 밖 API 자동화를 실제 추가할 때만 CI secret | 해당 automation job만 | repository/log/artifact/client 금지 |

Remotely-managed tunnel은 `--token-file` 또는 `TUNNEL_TOKEN_FILE`을 지원한다. command line과 service registry에 raw token을 직접 적는 것보다 Windows ACL로 제한한 token file을 선택한다. token file 방식은 `cloudflared` 2025.4.0 이상이 필요하다. [Cloudflare run parameters](https://developers.cloudflare.com/tunnel/advanced/run-parameters/)

Tunnel token은 connector 실행 권한이고 management API token은 tunnel/DNS CRUD 권한이다. 둘은 목적과 피해 범위가 다르므로 반드시 분리한다. token 노출 시 tunnel token을 rotate하고 모든 기존 replica가 새 token을 쓰도록 재설치한다. [Cloudflare tunnel tokens](https://developers.cloudflare.com/tunnel/advanced/tunnel-tokens/)

## 5. 권장 workflow 단위

| 파일/서비스 | Trigger | 핵심 gate | 배포 여부 |
|---|---|---|---|
| `.github/workflows/server-ci.yml` | `pull_request`, `push` + `server/**`, `contracts/**` | test, `bootJar`, checksum, artifact | 없음 |
| `.github/workflows/server-deploy.yml` | dev는 성공한 main SHA, prod는 `workflow_dispatch` | CI artifact SHA 확인, 전용 Windows runner, loopback health, rollback | Spring Boot origin만 |
| `.github/workflows/ios-ci.yml` | `pull_request`, `push`, manual + `ios/**`, `contracts/**` | `bash ios/scripts/test.sh`, 실패 `.xcresult` | 없음 |
| Xcode Cloud workflow | iOS 변경 branch/PR와 release 조건 | test; release lane은 clean archive와 TestFlight post-action | TestFlight |
| 별도 infra workflow/수동 runbook | hostname·Tunnel 변경 승인 때만 | Cloudflare API 최소 권한, rule 검증, external actuator 차단 | Tunnel/DNS/cloudflared service |

Windows self-hosted runner에는 `[self-hosted, Windows, X64, moneysnap-origin]`처럼 전용 label을 부여하고 이 repository의 deployment job만 받을 수 있게 한다. GitHub는 모든 지정 label과 group이 일치하는 runner로 job을 라우팅하며, runner group으로 repository 접근 범위를 제한할 수 있다. [self-hosted runner routing](https://docs.github.com/en/actions/reference/runners/self-hosted-runners), [runner labels](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/apply-labels), [runner groups](https://docs.github.com/en/actions/concepts/runners/runner-groups)

이 runner에서는 PR, `pull_request_target`, 임의 branch, 외부 fork code를 절대 실행하지 않는다. origin host에 DB/R2/Tunnel secret이 존재하므로 repository가 private이어도 write 권한과 workflow 변경 권한을 최소화하고 `.github/workflows/**`를 CODEOWNERS/branch protection 대상으로 둔다. GitHub는 public repository에서 self-hosted runner 사용을 거의 금지 수준으로 경고하며 private repository에서도 fork/PR 권한자가 persistent runner를 침해할 수 있다고 설명한다. [GitHub Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use), [managing runner access](https://docs.github.com/actions/hosting-your-own-runners/managing-access-to-self-hosted-runners-using-groups)

## 6. 구현 전 남은 사용자/외부 gate

다음은 repository 파일만으로 완료할 수 없다.

1. Windows origin을 GitHub self-hosted runner로 등록하고 전용 service account·label·runner 접근 범위를 설정한다.
2. Spring Boot를 실행할 Windows service wrapper와 release directory/ACL을 설치한다.
3. 최종 Bundle ID, Apple Team, App ID와 App Store Connect app record를 확정한다.
4. Mac/Xcode에서 첫 Xcode Cloud workflow와 첫 build를 시작한다.
5. 승인된 dev hostname으로 named Tunnel/DNS를 생성하고 `cloudflared` Windows service를 설치한다.
6. GitHub repository plan에서 private environment required reviewer가 실제 제공되는지 확인한다. 무료 범위에서는 제공되지 않는다는 전제로 production을 manual dispatch로 유지한다.

이 gate가 열리기 전에도 GitHub-hosted Backend CI, Apple credential·provisioning 없는 Simulator iOS CI, deployment script의 dry-run/static validation은 완성할 수 있다. 반면 실제 TestFlight upload, named Tunnel/DNS 생성, origin service 등록과 production secret 저장은 외부 상태 변경이므로 별도 승인과 실행 evidence가 필요하다.

# Money Snap CI/CD 운영 계약

> 상태: remote CI active, deployment·Apple activation pending
>
> 기준일: 2026-08-09

## 배포 lane

| Lane | 실행 위치 | Trigger | 결과 |
|---|---|---|---|
| server CI | GitHub-hosted `ubuntu-latest` + `windows-latest` | server·API contract 관련 pull request, `main` push, manual | Java 21 test, canonical JAR와 SHA-256 artifact, Windows deployment behavior test |
| server development CD | 전용 Windows self-hosted runner | server CI가 성공한 `main` push만 | loopback origin 교체, health smoke, 실패 시 이전 JAR 복구 |
| iOS CI | GitHub-hosted `macos-15` | iOS·contract pull request, `main` push, manual | signing 없는 고정 Simulator build/test, 393x852 visual evidence, 실패 `.xcresult` |
| iOS CD | Xcode Cloud | Apple workflow에서 승인한 branch/release condition | Apple-managed signing, archive, internal TestFlight |
| Tunnel/DNS | 승인된 infrastructure 작업 | hostname·외부 노출 AC 승인 | named Tunnel, DNS, `cloudflared` service |

Spring application release는 Cloudflare Tunnel lifecycle을 건드리지 않는다. 새 JAR마다 tunnel을 만들거나 token을 회전하지 않으며 `cloudflared`와 Spring Boot process를 독립적으로 운영한다.

## 서버 GitHub Actions

`.github/workflows/server-ci-cd.yml`은 다음 경계를 강제한다.

- workflow 전체 권한은 `contents: read`뿐이다.
- 모든 외부 action은 전체 commit SHA로 고정하고 옆 주석에 major version을 남긴다.
- Gradle cache는 `setup-gradle`의 open-source basic provider 하나만 사용하고 같은 action에서 wrapper를 검증한다.
- CI는 Neon, R2, Cloudflare secret을 받지 않는다.
- `contracts/**` 변경도 server와 iOS lane을 함께 실행해 공유 API 계약의 양쪽 소비자를 검증한다.
- test와 `bootJar`가 모두 통과한 canonical `moneysnap-server.jar`만 SHA-256 manifest와 함께 artifact가 된다.
- 별도 `windows-latest` job은 checksum 변조 거부, secret directory ACL과 이전 JAR·runner script·secret 복원을 실제 파일로 검증한다.
- deployment job은 `push`와 `refs/heads/main`을 동시에 검사하고 `[self-hosted, Windows, X64, moneysnap-dev]` label을 모두 요구한다.
- `server-development` environment secret은 deployment step에만 주입된다.
- pull request code는 secret이 있는 persistent self-hosted runner에서 실행하지 않는다.
- main deployment는 cancel하지 않고 concurrency로 하나씩 실행한다.

`.github/dependabot.yml`은 GitHub Actions reference를 매주 점검한다. SHA update PR도 일반 source 변경과 같은 리뷰·CI를 통과해야 한다.

## Windows origin 배포

호스트의 상세 계약은 `infra/windows/README.md`를 따른다. 핵심 순서는 다음과 같다.

1. workflow가 같은 run의 JAR와 checksum manifest를 전용 runner로 내려받는다.
2. `server/scripts/deploy.ps1`이 checksum을 확인하고 SHA별 release directory에 보관한다.
3. GitHub environment secret을 command line에 넣지 않고 directory ACL을 먼저 제한한 뒤 개별 secret file로 쓴다.
4. Windows Scheduled Task가 실행하는 `run-server.ps1`은 secret file을 process environment로 읽고 bootstrap에서 고정한 Java 21 절대 경로로 canonical current JAR을 foreground 실행한다.
5. `http://127.0.0.1:8080/actuator/health`가 `UP`이고 `components`가 없을 때만 current state를 확정한다.
6. 실패하면 이전 JAR, 같은 release의 `run-server.ps1`, secret file을 복원하고 health를 다시 확인한다.

자동 rollback은 JAR에만 안전하다. DB migration은 자동 down migration하지 않는다. production schema 변경은 이전 JAR과 호환되는 expand-first 순서를 별도 feature AC로 가져야 한다.

## GitHub 설정 계약

repository 파일을 push한 뒤 GitHub에서 다음 상태가 필요하다.

- Environment: `server-development`
- Environment secrets:
  - `NEON_RUNTIME_DATABASE_URL`
  - `NEON_RUNTIME_DATABASE_USERNAME`
  - `NEON_RUNTIME_DATABASE_PASSWORD`
  - `NEON_MIGRATION_DATABASE_URL`
  - `NEON_MIGRATION_DATABASE_USERNAME`
  - `NEON_MIGRATION_DATABASE_PASSWORD`
- Self-hosted runner labels: `self-hosted`, `Windows`, `X64`, `moneysnap-dev`
- runner access: public repository의 검증된 `main` deployment job에만 허용하며 PR·임의 branch code는 실행하지 않음
- branch protection: `main`에 server CI와 iOS CI가 적용되면 성공 check를 merge 조건으로 추가

repository는 public이며 `server-development` environment의 custom deployment branch policy는 `main` 하나로 제한한다. persistent Windows runner는 공개 repository 공격면을 가지므로 branch protection과 workflow 검증이 완료되기 전 등록하지 않는다. 자동 CD는 폐쇄형 development origin만 대상으로 하며 production/public 배포 workflow는 만들지 않는다.

## iOS CI와 Xcode Cloud

GitHub Actions의 `.github/workflows/ios-ci.yml`은 Apple credential 없이 `macos-15`의 Xcode 16.4, iPhone 16, iOS 18.5에서 `bash ios/scripts/test.sh`를 실행한다. UDID는 runner마다 달라 device·runtime으로 해석한다. 이어서 앱을 393x852로 캡처해 Figma 홈 `9:2` reference, overlay, diff와 수치 report를 7일 보관한다. 홈 기능 구현 전 diff는 report-only다. 실패할 때는 `.xcresult`도 3일 보관한다.

TestFlight CD는 Xcode Cloud가 소유한다. `ios/ci_scripts/ci_post_clone.sh`는 Xcode와 project/scheme을 post-clone 단계에서 검증한다. 최초 Mac/Xcode activation 때 다음 두 workflow를 만든다.

1. Pull request workflow: iOS 17 Simulator test만 실행하며 archive와 배포는 하지 않는다.
2. Main release workflow: test 성공 뒤 archive하고 internal TestFlight group에만 post-action으로 배포한다.

Xcode Cloud activation 전에 다음 Apple gate가 필요하다.

- 확정된 Bundle ID `com.ansandy.moneysnap`으로 explicit App ID 생성
- Apple Team 연결, explicit App ID와 App Store Connect app record 생성
- Mac/Xcode에서 첫 Xcode Cloud workflow와 첫 build 시작
- internal TestFlight tester group과 release start condition 확인

Xcode Cloud 기본 배포에는 GitHub-held `.p12`, provisioning profile 또는 App Store Connect API key를 추가하지 않는다. 별도 App Store Connect API 자동화가 실제로 필요해질 때만 최소 권한 key 작업을 연다.

## 현재 활성화 상태

| 항목 | 상태 |
|---|---|
| server workflow source와 정적 검증 | 준비 완료 |
| iOS workflow source와 Xcode Cloud hook | 준비 완료 |
| local Gradle test·canonical bootJar | 검증 완료 |
| GitHub `server-development` environment | 생성 완료, `main` 전용 branch policy, secret 0개 |
| GitHub remote workflow run | public draft PR #1에서 활성화, server CI 통과 |
| Windows self-hosted runner와 Scheduled Task | 미등록 |
| GitHub `server-development` secret | 6개 모두 미등록 |
| GitHub-hosted macOS native test | 첫 run에서 Swift 6 `AppTab` Sendable finding 확인, 수정 run 대기 |
| Xcode Cloud/TestFlight | Apple gate와 Mac/Xcode activation 대기 |
| Cloudflare named Tunnel/DNS | 별도 infrastructure 승인 작업 대기 |

조사 근거와 최신 action SHA는 `docs/CI_CD_RESEARCH.md`가 소유한다.

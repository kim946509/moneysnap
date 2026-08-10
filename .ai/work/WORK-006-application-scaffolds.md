---
id: WORK-006
status: verify
depends_on: [WORK-005]
owner: codex
---

# Spring Boot·SwiftUI 애플리케이션 scaffold

## Intent

Money Snap의 첫 기능 수직 슬라이스를 시작할 수 있도록 서버와 iOS 프로젝트의 실행·테스트 기반을 만든다.

## In scope

- Java 21, Spring Boot 4.1, Gradle 기반 `server` 프로젝트
- Web, Validation, Actuator, JPA, Flyway, PostgreSQL과 Testcontainers 테스트 기반
- 외부 운영 seam인 `/actuator/health`의 red → green bootstrap test
- iOS 17, SwiftUI, Swift Testing 기반 `ios` Xcode project
- `AppTab`, tab별 `NavigationStack`, `RouterPath`를 사용하는 최소 app shell
- iOS test target과 Mac에서 실행할 검증 스크립트
- 실제 검증 명령, 구조와 Windows/macOS 경계를 기준 문서와 `AGENTS.md`에 동기화

## Out of scope

- Snap·group·media·identity 기능 구현과 production schema
- Figma 화면의 시각 구현, asset 추출과 snapshot baseline
- Neon/R2 production 연결과 secret 발급
- Sign in with Apple, App ID 등록, signing, Xcode Cloud와 GitHub Actions
- Cloudflare Tunnel과 배포

## Acceptance criteria

- [x] `server` Gradle wrapper가 Java 21에서 테스트와 production build를 통과한다.
- [x] 서버 `/actuator/health`가 `UP`을 반환하고 상세 health 정보는 외부에 노출하지 않는다.
- [x] 서버 기본 실행은 Neon 환경변수를 요구하고 테스트는 외부 Neon에 접속하지 않는다.
- [x] `ios/MoneySnap.xcodeproj`에 app·unit test target과 iOS 17 deployment target이 있다.
- [x] SwiftUI app shell은 current baseline tab별 독립 `NavigationStack`과 `RouterPath`를 사용한다.
- [ ] iOS 테스트 source는 home 초기값과 router path 동작을 일반 `import MoneySnap`로 검증한다. macOS native 실행은 대기 중이다.
- [ ] Windows 정적 검증과 macOS one-command script 준비는 완료했다. macOS/Xcode 실제 build/test는 대기 중이다.
- [x] 최초 Code Review Graph full build와 change detection 결과가 기록된다.
- [x] 기준 문서와 `AGENTS.md`의 프로젝트 경로·명령이 실제 상태와 일치한다.

## Test seam

- 서버: HTTP management interface `GET /actuator/health`
- iOS: `AppTab` 기본 선택과 `RouterPath` navigation state

기존 `docs/ARCHITECTURE.md`와 사용자의 scaffold 진행 요청으로 이 public seam을 확정한다. feature 내부 구현이나 private method는 테스트하지 않는다.

## Verification

```text
cd server && .\gradlew.bat test
cd server && .\gradlew.bat bootJar
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
# macOS: ios/scripts/test.sh
git diff --check
```

## Evidence

- RED 1: Actuator dependency 추가 전 `healthIsAvailableWithoutExposingInternalDetails`가 예상대로 HTTP 404로 실패했다.
- RED 2: Neon 연결 분리와 기본 거부 정책 리뷰 보완 전 전체 테스트에서 `routesAreDeniedUntilAnAuthenticationPolicyIsImplemented`, `runtimeAndMigrationConnectionsRequireSeparateNeonVariables` 두 테스트가 실패했다.
- GREEN: `cd server; .\gradlew.bat test --no-daemon --console=plain` — Java 21, 3 tests, `BUILD SUCCESSFUL in 19s`.
- production build: `cd server; .\gradlew.bat bootJar --no-daemon --console=plain` — `BUILD SUCCESSFUL in 10s`, `build/libs/moneysnap-server-0.0.1-SNAPSHOT.jar` 생성.
- packaged JAR smoke: 임시 `18080` loopback port에서 `health=UP`, `components` 미노출, 미구현 `/v1`은 `403`; 검증 직후 process 종료 확인.
- Neon fail-fast smoke: 필수 Neon 변수 없이 packaged JAR 실행 시 exit 1을 확인했고, runtime auto-configuration을 끈 별도 실행에서도 migration 변수 누락으로 exit 1이 발생해 Flyway의 runtime datasource fallback이 차단됨을 확인했다.
- iOS static: `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1` — `MoneySnap iOS project static validation: OK`.
- 환경 경계: Windows에 `swift`와 `xcodebuild`가 없어 `bash ios/scripts/test.sh`의 native compile/test는 실행하지 않았다.
- 리뷰: 명세·기준 리뷰에서 Neon runtime/Flyway fallback, 문서 경로, iOS public test seam, Spring Security 누락을 찾았다. 별도 필수 변수·계약 테스트, 문서 동기화, public 타입과 일반 import, health-only permit/default-deny security로 모두 수정했다.
- 리뷰 판단: placeholder View의 snapshot 검증과 domain Snap ID value type은 각각 Figma vertical slice와 첫 Snap domain 작업으로 미룬다. 현재 scaffold AC에 추가하지 않는다.

## Agent rules impact

- 영향 여부: yes
- 근거: 실제 애플리케이션 경로와 검증 명령이 처음 생긴다.
- 처리 결과: `docs/ARCHITECTURE.md`, `docs/ADR.md`, `docs/TECHNICAL_DESIGN_PROPOSAL.md`, 인프라 README를 먼저 갱신한 뒤 `AGENTS.md`의 단계·stack·규칙·실행 명령을 동기화했다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: 최초 full build 후 리뷰 수정 묶음에 incremental update
- base: `HEAD`
- risk: medium
- 최초 full build: 19 files, 52 nodes, 184 edges, 1 flow, 6 communities, errors 0.
- 최종 incremental update: 53 files re-parsed, errors 0. 최종 minimal context는 20 files, 66 nodes, 231 edges, risk 0.50이었다.
- change detection: 33 changed symbols, affected flow 0, heuristic test gaps 30. 서버 테스트는 graph가 Test로 인식했고 통과했다. Swift Testing의 `@Test` 함수는 graph가 test로 분류하지 못했으나 `AppShellTests`가 public seam 두 개를 직접 검증한다. native 실행은 위 macOS gate로 남긴다.
- findings와 처리 결과: 별도 코드 리뷰 finding은 모두 수정했다. placeholder presentation/view gap은 시각 구현 범위 밖이며 Figma snapshot 작업에서 처리한다.

## Decisions and risks

- 결정: Spring Boot 4.1.0, Java 21, Gradle은 Spring 공식 지원 범위를 사용한다.
- 결정: iOS deployment target은 Observation을 사용할 수 있는 iOS 17.0으로 시작한다.
- 결정: Java package와 repository iOS project identifier는 `com.ansandy.moneysnap`이다. Apple App ID는 아직 등록하지 않았고 외부 등록 전 최종 사용을 재확인한다.
- 위험: Windows에는 Swift/Xcode가 없어 iOS compile·Simulator·snapshot 검증은 macOS lane에서 완료해야 한다.

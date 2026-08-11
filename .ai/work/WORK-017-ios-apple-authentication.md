---
id: WORK-017
status: verify
depends_on: [WORK-016]
owner: codex
---

# iOS Sign in with Apple과 지속 session

## Intent

iOS 사용자가 Sign in with Apple 단독으로 로그인하고 Keychain session을 복구해 로그인 화면 깜빡임 없이 앱을 사용하며 My 화면에서 현재 기기 로그아웃과 재인증 계정 탈퇴를 수행한다.

## In scope

- `AuthenticationServices` Sign in with Apple credential·nonce 획득
- Spring Boot `/api/v1/auth/apple`, `/refresh`, `/logout`, `DELETE /api/v1/account` URLSession adapter
- access·refresh token과 만료 시각의 iOS Keychain 저장
- cold launch session 복구, access 만료 전 refresh, 확정된 401에서만 signed-out 전환
- 일시적 network 복구 실패 시 로그인 화면 대신 재시도 상태 유지
- Figma My `77:798` 구조를 따르는 My 화면과 계정 설정 진입
- 현재 기기 로그아웃, 탈퇴 안내·Apple 재인증·성공 후 Keychain 삭제
- Swift unit/API contract tests, Windows project 검증, macOS native test와 393x852 My visual evidence

## Out of scope

- Apple Developer explicit App ID, entitlement activation과 실제 Apple credential 전송
- App Store Connect/Xcode Cloud activation과 실제 기기 로그인
- 사용자 프로필·월간 통계 서버 API; My 화면은 Figma fixture를 사용한다.
- Figma에 존재하지 않는 로그인 frame의 pixel-diff 완료 판정
- Snap·group·archive 기능

## Acceptance criteria

- [x] 저장된 session이 없으면 Sign in with Apple 단일 액션만 있는 로그인 화면을 표시한다.
- [x] 유효한 Keychain access session은 로그인 화면을 노출하지 않고 Home으로 복구한다.
- [x] access가 만료되고 refresh가 유효하면 token을 회전·저장한 뒤 Home으로 복구한다.
- [x] refresh 401은 Keychain을 지우고 로그인으로 전환하며, network 실패는 credential을 보존한 재시도 화면을 표시한다.
- [x] Sign in with Apple credential은 nonce와 함께 서버로 전송되고 성공 session만 Keychain에 저장한다.
- [x] 로그아웃 성공 또는 이미 무효인 session은 현재 Keychain session을 지우며 일시적 실패는 로그인 완료로 가장하지 않는다.
- [x] 계정 탈퇴는 삭제 범위 안내·Apple 재인증 뒤 실행하며 성공 때만 Keychain을 지운다.
- [ ] My 화면은 Figma `77:798`의 393x852 레이아웃과 기존 visual threshold를 통과하고 계정 설정이 접근 가능하다.
- [x] private key, Apple authorization code·identity token, raw session token을 로그·소스·UserDefaults에 남기지 않는다.

## Test seam

- model seam: fake authentication API와 in-memory session store로 restore·refresh·login·logout·delete 상태 전이를 먼저 실패시킨다.
- HTTP seam: custom URLProtocol로 endpoint, method, bearer header, JSON envelope와 200/204/401/5xx 변환을 먼저 실패시킨다.
- Keychain seam: application은 `SessionStore`만 알고 production adapter만 Security framework를 사용한다.
- visual seam: My fixture를 `MONEYSNAP_VISUAL_SCENARIO=my`로 고정해 393x852 reference/app/overlay/diff를 생성한다.

## Verification

```text
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
bash ios/scripts/test.sh
bash ios/scripts/capture-visual-baseline.sh
git diff --check
```

## Evidence

- 실행 명령:
  - `cd server; .\gradlew.bat test --tests "*AppleIdentityTokenVerifierTests" --no-daemon --console=plain` (nonce verifier 구현 전·후)
  - `cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.identity.AuthenticationHttpIntegrationTests" --tests "com.ansandy.moneysnap.identity.AccountDeletionHttpIntegrationTests" --tests "com.ansandy.moneysnap.identity.AppleAccountEventHttpIntegrationTests" --no-daemon --console=plain` (오류 계약 구현 전·후)
  - `cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.identity.AppleIdentityTokenVerifierTests" --tests "com.ansandy.moneysnap.identity.AppleAuthorizationPersistenceIntegrationTests" --no-daemon --console=plain`
  - `cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.identity.ApiErrorResponseTests" --no-daemon --console=plain` (correlation ID log 구현 전·후)
  - `cd server; .\gradlew.bat test --no-daemon --console=plain`
  - `cd server; .\gradlew.bat bootJar --no-daemon --console=plain`
  - `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1`
  - `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1`
  - `powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1`
  - OpenAPI YAML parse (`openapi=3.1.0`, paths 5, schemas 5)
  - `git diff --check`
- 결과:
  - claim hash를 raw nonce로 재전송하는 테스트가 구현 전 2건 실패했고 raw nonce SHA-256 검증 구현 후 verifier 7건 통과
  - 안정된 오류 `code`와 `correlationId` 구현 전 인증 HTTP 통합테스트 7건 실패, 구현 후 대상 21건 통과
  - production hasher와 독립된 nonce fixture 검증 9건 통과
  - correlation ID가 응답과 안전한 서버 로그에 동일하게 연결되는 단위테스트가 구현 전 실패, 구현 후 통과
  - 서버 전체 90 tests, 실패·오류·skip 0 통과
  - server production `bootJar` 생성 통과
  - iOS project·Home/My visual baseline·CI/CD 정적 계약과 OpenAPI YAML parse 통과
  - whitespace 오류 없음
  - macOS native test와 Home/My screenshot diff는 remote CI 대기
- 리뷰:
  - spec/standards 1차 리뷰의 실행 중 refresh, remote deletion/local cleanup, fractional `Instant`, 탈퇴 확인 순서, nonce replay, actor reentrancy, URLProtocol race, release visual seam finding을 TDD로 수정
  - 최종 spec 재리뷰에서 비시각 AC·scope·wire contract 위반 없음; standards 재리뷰의 OpenAPI unknown-field 불일치와 추적 불가능한 correlation ID를 실제 decoding 계약과 안전한 server log로 해소

## Agent rules impact

- 영향 여부: yes
- 근거: iOS 인증 경계와 다음 기능 단계가 완료 시 바뀐다.
- 처리 결과: 완료 시 기준 문서를 먼저 갱신하고 `AGENTS.md` 현재 단계·검증 명령을 동기화한다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: `9eba7e0` 기준 staged incremental update 완료 (24 files, 신규 9 nodes·36 edges 반영)
- base: `9eba7e0`
- risk: high 예상 (credential persistence, authentication state gate, destructive account deletion)
- findings와 처리 결과: risk medium `0.60`; 도구가 visual 전용 in-memory adapter와 Swift test linkage를 일반 test gap으로 보고했으며, 해당 경로는 model/API/Keychain/nonce 테스트와 remote Home/My visual CI로 검증한다. nonce fixture tautology와 API 오류 계약 finding은 독립 fixture, canonical OpenAPI, controller/security contract test로 해소했다.

## Decisions and risks

- refresh session은 UserDefaults가 아닌 Keychain generic-password item 하나에 JSON으로 저장한다.
- login frame은 현재 Figma 파일에 없으므로 native Sign in with Apple button과 기존 Money Snap visual tokens로만 구현하며 Figma pixel parity를 허위로 완료 처리하지 않는다.
- Figma My `77:798`의 프로필·통계 값은 profile API가 없는 현재 단계에서 deterministic fixture이며 이후 My 기능에서 실제 조회로 교체한다.
- 실제 Apple sign-in은 explicit App ID와 Sign in with Apple capability 활성화 뒤에만 device에서 검증할 수 있다.

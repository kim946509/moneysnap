---
id: WORK-032
status: proposed
depends_on: [WORK-031, WORK-028]
owner: codex
---

# Stage 9 실제 프로필과 마이 요약

## Intent

로그인한 사용자가 fixture가 아닌 자신의 display name과 오늘·이번 달 개인 Snap 수, 현재 그룹 수를 마이에서 확인하고 기존 로그아웃·계정 탈퇴를 그대로 사용할 수 있게 한다.

## In scope

- authenticated `GET /api/v1/account/summary`와 OpenAPI exact response/error contract
- identity에 저장된 실제 display name과 `MoneySnap 사용자` fallback
- server `Clock`과 제출된 tzdb region `ZoneId` 또는 `UTC`를 기준으로 한 today·current month 경계
- personal Snap today count, current-month Snap count, current membership group count
- Figma 마이 `77:798`의 profile·summary·기존 logout/delete UI를 production API state에 연결
- loading·retry·session rejection과 logout/account-delete 회귀
- server unit·PostgreSQL HTTP integration·OpenAPI·Swift model/API·XCUITest·393x852 visual 검증

## Out of scope

- display name 편집, profile 사진 업로드, email·Apple subject·user ID 노출
- 금액 합계, 예산, 연속 기록 streak, 월간 차트와 알림 설정
- 그룹별 통계, 다른 사용자의 profile, 공개 profile page
- 로그아웃·재인증 계정 탈퇴 정책 또는 Apple revoke 구현을 다시 여는 일
- server deployment, live Apple·Neon·R2 호출

## Acceptance criteria

- [ ] bearer user는 자신의 summary만 받고 다른 user의 식별자를 request로 지정할 수 없다.
- [ ] response exact field는 `displayName`, `todaySnapCount`, `monthSnapCount`, `groupCount` 네 개뿐이며 Apple subject/email, internal user/session ID, token을 포함하지 않는다.
- [ ] 첫 로그인에서 저장된 valid Apple full name이 있으면 trim된 실제 `displayName`을 반환하고, 이름이 없거나 invalid였던 계정은 정확히 `MoneySnap 사용자`를 반환한다. request마다 임의 이름이나 user ID suffix를 만들지 않는다.
- [ ] avatar는 iOS에서 display name의 첫 grapheme를 쓸 수 있을 때 그것을 사용하고, 빈 값·표시 불가 값이면 MoneySnap mark를 사용한다. 원격 profile image URL이나 편집 control은 만들지 않는다.
- [ ] `timeZone`은 tzdb available region ID 또는 `UTC`만 허용하고 numeric offset·short alias·malformed 값은 `400 INVALID_REQUEST`와 `correlationId`로 거부한다.
- [ ] server `Clock`의 instant를 요청 zone으로 변환한 local date와 YearMonth가 today/current month의 유일한 기준이며 client가 날짜나 count를 제출하지 않는다.
- [ ] `todaySnapCount`와 `monthSnapCount`는 owner의 nondeleted 개인 Snap 행을 각각 한 번만 센다. 같은 Snap의 group share 수는 count를 늘리지 않고 image 유무도 count 의미를 바꾸지 않는다.
- [ ] Snap의 저장된 immutable `localDay`를 current date·month label과 비교하며 device zone 변경이 과거 Snap의 `localDay`를 다시 계산하지 않는다. 월말·연말·DST 경계를 fixed Clock 테스트로 검증한다.
- [ ] `groupCount`는 owner/member 구분 없이 현재 active membership만 세고, 삭제된 group과 leave/remove가 끝난 membership은 제외하며 같은 group share 수와 무관하다.
- [ ] account summary read는 Snap/group 테이블 수에 비례한 N+1 query를 만들지 않고 한 요청의 bounded aggregate query로 처리한다.
- [ ] bearer가 없거나 만료·폐기된 경우 canonical `401 SESSION_REJECTED`를 반환하고 iOS는 summary를 stale 사용자 데이터로 유지하지 않은 채 기존 인증 복구 경계로 넘긴다.
- [ ] My는 실제 API의 display name·세 count를 하나의 whole response로 표시하며 loading·retry·malformed 또는 전체 실패를 성공 fixture나 부분 성공으로 가장하지 않는다.
- [ ] 기존 현재-device 로그아웃은 그 session과 Keychain만 지우고, 계정 탈퇴는 안내→Apple 재인증→명시적 확인→server 성공 뒤 로컬 삭제 순서를 그대로 유지한다.
- [ ] 계정 탈퇴 실패 중에는 count를 0으로 바꾸거나 signed-out 성공 화면으로 전환하지 않고 correlation ID를 보존한다.
- [ ] profile, 세 summary 값, logout과 계정 탈퇴 action은 VoiceOver에서 의미가 중복되지 않고 44pt 이상 target을 가지며, Dynamic Type에서 잘리거나 action 순서가 뒤섞이지 않는다.
- [ ] exact source와 같은 실제 profile/content 상태만 Figma `77:798` 393x852 reference·승인 threshold를 통과한다. 별도 source가 없는 empty-count·오류 변형은 XCUITest·accessibility 기능 evidence와 design precondition으로 판정하고 DEBUG fixture는 release build에서 제거된다.

## Test seam

- TDD profile seam: valid name·fallback·first grapheme/MoneySnap mark mapping을 서버와 Swift 순수 테스트에서 먼저 실패시킨다.
- aggregate seam: fixed `Clock`, 여러 zone·월말·연말, 두 owner, deleted/shared Snap과 active/left/deleted membership fixture로 정확한 count를 PostgreSQL HTTP 테스트에서 검증한다.
- authorization seam: principal 외 owner selector가 없고 missing/revoked bearer가 canonical 401인 exact contract를 검증한다.
- query seam: representative rows에서도 aggregate query 수가 고정인지 datasource observation으로 검증하고 entity 전체 hydration을 허용하지 않는다.
- iOS seam: summary client spy와 URLProtocol로 loading/content/retry/401, real display fallback과 logout/delete 회귀를 먼저 실패시킨다.
- UI·visual seam: WORK-020 My scenario를 실제 summary fixture로 확장하되 기존 `77:798` threshold를 완화하지 않는다.
- 긴 회귀 테스트는 targeted red/green 뒤 기능이 완성된 시점에 server 전체·bootJar·native UI·전체 visual suite를 한 번 실행한다.

## Verification

```text
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.identity.AccountSummary*Tests" --no-daemon --console=plain
cd server; .\gradlew.bat test --no-daemon --console=plain
cd server; .\gradlew.bat bootJar --no-daemon --console=plain
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
bash ios/scripts/test.sh
bash ios/scripts/capture-visual-baseline.sh
git diff --check
```

## Evidence

- 실행 명령: 구현 전 identity fallback·Snap/group count·My frame 계약 확인, 구현 후 위 명령 기록 예정
- 결과: 2026-08-13 작업 항목 작성 시점에는 계획만 고정했으며 runtime 완료를 주장하지 않음
- 리뷰: 사용자가 Stage 9~10을 포함한 후속 MVP 작업 진행을 포괄 승인함

## Agent rules impact

- 영향 여부: yes
- 근거: 실제 account summary API, profile fallback과 calendar aggregate 규칙이 identity/Snap/group 경계와 현재 단계 설명을 확장한다.
- 처리 결과: canonical OpenAPI·서비스/UI·아키텍처 문서를 먼저 동기화한 뒤 완료 시 `AGENTS.md` 현재 단계와 검증 근거를 갱신한다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: stage 시작 SHA를 고정 base로 한 incremental update
- base: WORK-032 구현 시작 시 고정
- risk: high (cross-feature aggregate, owner privacy, calendar boundary, destructive account-action regression)
- findings와 처리 결과: identity·snap·group query 영향과 iOS 인증 상태 전이를 standard detail로 검사하고 actionable finding은 TDD 수정 후 재update한다.

## Decisions and risks

- summary는 화면 전용 read model 하나로 만들고 identity, snap, group entity를 서로 직접 참조하는 범용 profile service를 만들지 않는다.
- count는 개인 Snap과 current membership의 단순 개수만 제공하며 금액·행동 점수·streak로 제품 범위를 넓히지 않는다.
- server가 현재 날짜를 정하고 iOS는 zone만 제출한다. 저장된 `localDay` 자체는 어떤 zone에서도 다시 쓰지 않는다.
- 기존 My fixture가 실제 profile처럼 보였더라도 production summary 성공 증거로 사용하지 않는다.
- account delete와 logout은 WORK-017의 검증된 command를 그대로 재사용하고 summary 작업이 위험 action의 의미를 바꾸지 않는다.

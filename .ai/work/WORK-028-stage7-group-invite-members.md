---
id: WORK-028
status: proposed
depends_on: [WORK-027]
owner: codex
---

# Stage 7 그룹 초대·가입·멤버 lifecycle

## Intent

owner가 기간 제한 단일 초대를 안전하게 발급하고 인증 사용자가 정책을 확인한 뒤 원자적으로 가입하며, owner/member lifecycle과 계정 삭제 경계를 개인 Snap 손실 없이 완성한다.

## In scope

- 최소 128-bit entropy invite 발급·재발급·폐기와 hash-only persistence
- `issuedAt + 168시간` 만료, group당 active invite 하나와 reissue revoke
- 인증된 invite preview, body-only join, actor-scoped join idempotency와 capacity transaction
- member 목록, member self-leave, owner member removal과 owner/non-owner 권한
- owner account deletion과 member account deletion이 group/membership/personal Snap에 미치는 cascade 통합
- iOS 초대 발급·재발급, preview→join, member 관리·탈퇴 UI
- 서버 단위·HTTP/PostgreSQL integration, Swift model/API, XCUITest와 Figma 393x852 visual 검증

## Out of scope

- 초대 원문 재조회, 영구 링크, URL path/query token, 공개 group discovery
- owner 양도, owner self-leave, owner 제거, 복수 관리자와 초대별 사용 횟수 설정
- 연락처·문자·메일 발송 integration과 universal link/deep link 자동 가입
- 개인 Snap 공유 command와 visible/hidden group projection
- 아직 존재하지 않는 `snap_shares`의 탈퇴·제거·group/account 삭제 cascade; `WORK-029` schema 도입 뒤 Stage 7 lifecycle 회귀로 검증
- live Neon 배포, push notification, analytics와 외부 secret 변경

## Acceptance criteria

- [ ] owner 발급은 cryptographically secure random source로 최소 128-bit entropy 원문을 만들고 성공 response에서 한 번만 반환하며 DB에는 원문이 아닌 hash만 저장한다.
- [ ] iOS owner 화면은 발급 직후 원문을 한 번 보여주고 system share sheet 없이 pasteboard에 `localOnly`와 invite `expiresAt` 이하의 expiration을 지정해 복사할 수 있다. recipient는 인증 후 manual paste field에 code를 입력해 preview→join을 진행하며 URL/deep link/clipboard 자동 읽기는 MVP에 추가하지 않는다.
- [ ] 초대 원문은 application/access log, analytics, exception, URL path/query와 persistence에 나타나지 않고 token을 받는 preview·join 요청은 인증된 `POST` body를 사용한다.
- [ ] 초대는 server `Clock` 기준 정확히 `issuedAt + 168시간`에 만료하고 경계 직전은 유효, 경계 시각부터 신규 가입은 거부된다.
- [ ] 한 group에는 nonexpired·nonrevoked active invite가 하나만 존재하고 DB constraint/transaction이 동시 발급에서도 이를 보장한다.
- [ ] owner가 재발급하면 이전 active invite를 같은 transaction에서 revoke하고 새 원문만 한 번 반환하며, 이전 code의 preview·신규 join은 즉시 실패한다.
- [ ] owner는 active invite를 폐기할 수 있고 member·비회원은 발급·재발급·폐기할 수 없다.
- [ ] 인증 사용자는 가입 확정 전에 group name과 immutable amount visibility만 포함한 preview를 보고, preview 자체는 membership을 만들지 않는다.
- [ ] expired·revoked·unknown invite는 동일한 안전한 실패 계약으로 거부되어 group 존재나 상태를 불필요하게 누설하지 않는다.
- [ ] 신규 join은 owner 포함 현재 membership이 20명 미만일 때 capacity check와 membership insert를 하나의 PostgreSQL transaction으로 수행한다.
- [ ] 20번째 자리를 두 actor가 동시에 요청해도 최대 한 명만 가입하고 총 membership은 절대 20명을 넘지 않는다.
- [ ] 이미 같은 group의 member인 actor가 가입을 재시도하면 새 membership 없이 멱등 성공한다.
- [ ] 같은 actor·`clientMutationId`로 성공한 join replay는 invite의 현재 만료·폐기 상태보다 먼저 최초 결과를 반환하고, 같은 mutation ID의 다른 semantic payload는 최초 결과를 보존한 채 conflict로 거부된다.
- [ ] join transaction 실패는 mutation reservation과 membership을 함께 rollback해 올바른 동일 command retry가 성공할 수 있다.
- [ ] member 목록은 현재 member에게만 최소 profile fallback(display name과 첫 grapheme 또는 MoneySnap mark), role을 제공하고 invite hash·원문이나 계정 credential을 포함하지 않는다.
- [ ] member는 self-leave만 수행하고 owner는 member만 제거할 수 있다. owner self-leave·owner 제거·role 양도 command와 UI는 존재하지 않는다.
- [ ] self-leave와 owner removal은 현재 Stage 7 schema의 해당 membership을 제거하고 actor의 개인 Snap을 삭제하지 않는다.
- [ ] owner의 group 삭제는 현재 Stage 7 schema의 group과 모든 membership을 제거하지만 모든 참여자의 개인 Snap을 보존한다.
- [ ] owner 계정 탈퇴는 소유 group과 membership을 먼저 삭제하고 account cascade가 owner 개인 Snap을 삭제한다. 다른 member의 개인 Snap은 보존된다.
- [ ] member 계정 탈퇴는 해당 membership과 member 자신의 account data를 삭제하되 다른 member와 group owner의 개인 Snap을 삭제하지 않는다.
- [ ] OpenAPI example, 서버 exact-field HTTP response와 iOS fixture가 invite preview/join/member lifecycle wire shape를 공유한다.
- [ ] iOS는 owner에게만 발급·재발급·폐기·member 제거를, member에게만 self-leave를 노출하고 destructive action은 명시적 confirmation과 실패 상태를 가진다.
- [ ] preview 화면은 group name과 공개/비공개 의미를 join action보다 먼저 보여주며 만료·폐기·정원 초과를 구분 가능한 사용자 상태로 표시한다.
- [ ] Swift test가 pasteboard adapter의 `localOnly`·bounded expiration option을 검증하고, XCUITest가 owner 발급/복사/재발급, recipient manual paste→preview/join/replay, 20명 full, self-leave/removal과 권한 부정 흐름을 deterministic fixture로 검증한다.
- [ ] 초대·가입·member 관리 중 정확한 Figma frame node·reference·checksum이 canonical manifest에 고정된 상태만 393x852 threshold gate를 적용한다.
- [ ] exact Figma node/reference가 없는 보조 오류 상태는 XCUITest·accessibility 기능 evidence로 판정하되, 핵심 초대·preview/join·member 관리 화면 자체의 reference가 없으면 기능 green까지만 기록하고 작업은 `design-gated`로 남긴다. 핵심 reference를 확보해 manifest/diff를 통과하기 전에는 `done`으로 전환하지 않는다.

## Test seam

- TDD Red 1: injected `Clock`과 secure random seam으로 entropy 길이, hash-only, 168시간 경계와 one-active/reissue revoke domain test를 먼저 실패시킨다.
- TDD Red 2: PostgreSQL 18 동시 integration test로 active invite uniqueness, 20명 capacity, join replay-before-expiry와 rollback을 먼저 실패시킨다.
- TDD Red 3: controller capture/log test와 exact JSON test로 raw code가 body/one-time response 경계 밖에 나타나는 회귀를 먼저 실패시킨다.
- TDD Red 4: account deletion integration fixture로 owner/member lifecycle 이후 개인 Snap 보존·삭제 경계를 먼저 실패시킨다.
- TDD Red 5: injected client Swift model test와 DEBUG XCUITest로 preview→join, owner/member action visibility와 failure state를 먼저 실패시킨다.
- visual seam: exact canonical Figma node/reference가 있는 상태만 393x852 reference/app/overlay/diff/report를 생성한다. 나머지는 기능 evidence와 미확보 node를 기록하고 token·개인 식별 정보는 fixture artifact에 넣지 않는다.
- focused Green 뒤에만 서버 전체 test·bootJar, iOS native/UI 전체 test와 전체 visual capture를 장시간 회귀로 실행한다.

## Verification

```text
cd server; .\gradlew.bat test --no-daemon --console=plain
cd server; .\gradlew.bat bootJar --no-daemon --console=plain
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
bash ios/scripts/test.sh
bash ios/scripts/capture-visual-baseline.sh
git diff --check
```

## Evidence

- 실행 명령: 구현 전이므로 없음
- 결과: `proposed`; `WORK-027` 완료 뒤 Red부터 기록
- 리뷰: 2026-08-13 사용자가 전체 MVP를 단계별 TDD·통합·visual 검증과 기능별 commit으로 계속 진행하도록 승인함

## Agent rules impact

- 영향 여부: yes
- 근거: invite security, 20명 원자성, group/account lifecycle이 실제 runtime gate가 되며 완료 시 현재 프로젝트 단계와 검증 근거가 바뀐다.
- 처리 결과: 구현 완료 시 canonical 정책과 부정 권한 테스트를 대조하고 `AGENTS.md` 현재 단계·검증 증거를 동기화한다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: stage 시작 SHA를 고정 base로 한 incremental update
- base: `WORK-028` 구현 시작 시 고정
- risk: high (secret handling, authorization, concurrency, destructive account lifecycle)
- findings와 처리 결과: invite·membership·identity cascade와 iOS action 변경 묶음마다 standard detail로 검사하고 finding은 TDD 수정·전체 회귀·재update한다.

## Decisions and risks

- 2026-08-13 사용자 승인을 기록하되 의존 작업 완료 전까지 상태는 `proposed`로 유지한다.
- `depends_on: [WORK-027]`은 실제 group·membership schema/API 의존이면서 사용자의 Stage 7 직렬 완료 gate다. media 구현에는 직접 compile/schema 의존하지 않는다.
- Stage 7 lifecycle은 현재 존재하는 group/membership/account 관계까지만 완료한다. `snap_shares`가 `WORK-029`에서 생기면 self-leave·removal·group delete·owner/member account deletion의 share cascade를 같은 canonical fixture로 다시 검증한다.
- invite 원문을 편의상 GET/query/deep-link parameter로 전달하지 않는다. share sheet 등 OS 외부 전달은 후속 범위다.
- CSPRNG·hash·transaction은 concrete group feature 내부에 두고 범용 token framework를 만들지 않는다.
- lifecycle command는 관계를 삭제할 뿐 개인 Snap 삭제 권한을 획득하지 않는다. 계정 탈퇴만 해당 actor 개인 데이터 cascade를 소유한다.

---
id: WORK-027
status: proposed
depends_on: [WORK-026]
owner: codex
---

# Stage 7 그룹 생성·목록·삭제

## Intent

로그인한 사용자가 금액 공개 정책이 고정된 소규모 그룹을 만들고 자신이 속한 그룹만 목록에서 확인하며, owner가 그룹을 안전하게 삭제할 수 있게 한다.

## In scope

- `group` feature의 group·membership Flyway schema와 owner 권한 경계
- 그룹 생성, 현재 actor의 그룹 목록, 단일 그룹 기본 정보 조회, owner 그룹 삭제 API와 OpenAPI contract
- owner 1명·member role, owner 포함 최대 20명이라는 domain invariant
- trim 후 1~30 grapheme cluster 이름, 같은 owner의 중복 이름 허용
- 생성 시 확정되고 변경할 수 없는 amount visibility
- iOS 그룹 탭 목록, 빈 상태, 생성 sheet, 생성 직후 목록 반영과 owner 삭제 흐름
- 서버 단위·HTTP/PostgreSQL integration, Swift model/API, XCUITest와 Figma 393x852 visual 검증

## Out of scope

- 초대 발급·preview·가입·member 탈퇴/제거; `WORK-028`이 소유한다.
- 개인 Snap 공유 command와 그룹 projection; `WORK-029`, `WORK-030`이 소유한다.
- 아직 존재하지 않는 `snap_shares`의 group/member/account lifecycle cascade 검증; schema 도입 뒤 `WORK-029`, `WORK-030`이 회귀로 소유한다.
- owner 양도, 복수 관리자, owner self-leave, amount visibility 변경 endpoint
- 그룹 이름 uniqueness, 검색, 공개 그룹 탐색, 채팅·댓글·좋아요·정산
- live Neon 배포, 외부 secret·DNS·인프라 변경

## Acceptance criteria

- [ ] 인증된 actor가 `clientMutationId`, trim 후 1~30 grapheme cluster 이름과 공개/비공개 amount visibility를 제출하면 group과 owner membership이 하나의 transaction으로 생성되고, 생성 actor만 owner가 된다.
- [ ] 같은 actor·mutation ID·같은 normalized create payload는 최초 group과 receipt를 재생하고, 같은 key의 다른 name/visibility는 원본을 보존한 채 `409 MUTATION_CONFLICT`다. 다른 actor는 같은 key를 독립 사용하며 동시 동일 요청도 group 하나만 만든다.
- [ ] 공백뿐인 이름, trim 후 0 또는 31개 이상 grapheme cluster, 정의되지 않은 visibility나 unknown JSON property는 `400 INVALID_REQUEST`와 `correlationId`로 거부되며 group·membership을 만들지 않는다.
- [ ] Unicode grapheme cluster 경계는 Java code point나 UTF-16 length로 대신하지 않고 조합 문자·emoji fixture로 검증한다.
- [ ] 같은 owner가 trim 결과까지 같은 이름인 서로 다른 그룹을 여러 번 만들 수 있고 이름에 owner-scoped unique constraint를 두지 않는다.
- [ ] amount visibility는 생성 시 저장된 뒤 변경 command·endpoint·iOS control이 존재하지 않으며, 생성/목록/상세 representation에서 사용자가 공개/비공개를 명확히 확인한다.
- [ ] 그룹은 정확히 owner 한 명을 가지며 owner를 membership 수에 포함한다. 후속 가입을 포함한 모든 write 경계가 총 20명을 넘길 수 없는 DB/domain 기반을 제공한다.
- [ ] 목록은 현재 actor가 active member인 그룹만 반환하고 role, trimmed name, immutable visibility와 필요한 최소 식별자만 포함하며 다른 사용자의 그룹 존재를 누설하지 않는다.
- [ ] 존재하지 않는 group과 actor가 속하지 않은 group은 외부에서 구별되지 않는 `404 NOT_ACCESSIBLE` 계약을 사용한다.
- [ ] owner만 새 `X-Client-Mutation-Id`로 group을 삭제할 수 있고 member·비회원의 삭제는 거부된다. 현재 Stage 7 schema에서 삭제는 group과 membership을 제거하되 어느 사용자의 개인 Snap도 삭제하지 않는다.
- [ ] 같은 actor·mutation ID·같은 group delete replay는 이미 삭제됐어도 `204`, 같은 key를 다른 group에 쓰면 `409 MUTATION_CONFLICT`, 새 key의 unknown/foreign group은 `NOT_ACCESSIBLE`이다. iOS commit-unknown retry는 같은 group/key만 재사용한다.
- [ ] 삭제된 group은 즉시 목록·상세에서 사라지고 같은 group에 대한 후속 접근은 `NOT_ACCESSIBLE`이다.
- [ ] bearer 없음·만료·폐기 session은 canonical `401 SESSION_REJECTED`를 반환하고, 예상된 persistence 실패는 내부 정보 없이 correlation ID를 가진 canonical error로 정규화한다.
- [ ] OpenAPI example, 서버 exact-field HTTP response와 iOS consumer fixture가 같은 group wire shape를 사용한다.
- [ ] iOS 그룹 탭은 loading·empty·content·retry 상태를 구분하고 빈 상태에서 그룹 생성으로 진입하며, 생성 성공을 한 번만 목록에 반영한다.
- [ ] 생성 UI는 이름과 공개/비공개 두 핵심 입력만 요구하고 visibility가 생성 후 바뀌지 않는다는 의미를 action 전에 전달한다.
- [ ] owner 삭제 UI는 destructive confirmation을 요구하고 실패를 성공으로 가장하지 않으며, member에게 owner 전용 삭제 action을 노출하지 않는다.
- [ ] create의 transport·5xx·malformed-response 결과 불명은 같은 immutable command와 mutation ID로만 재시도하고 자동으로 새 key를 만들어 중복 그룹을 만들지 않는다.
- [ ] 그룹 목록·생성·삭제 시나리오는 VoiceOver label/trait, Dynamic Type, 44pt 이상 touch target과 reduce-motion 대체를 통과한다.
- [ ] group list `75:86`과 create `77:480` 중 exact source 상태만 visual manifest에 고정해 iPhone 16 393x852 threshold를 통과한다. 별도 source가 확인되지 않은 delete confirmation·오류 상태는 XCUITest·accessibility 기능 evidence와 design precondition으로 판정하며 임의 pixel parity를 주장하지 않는다.

## Test seam

- TDD Red 1: `GroupName`, role과 immutable visibility 순수 domain test를 먼저 실패시켜 grapheme·trim·중복 이름 정책을 고정한다.
- TDD Red 2: PostgreSQL 18+Flyway HTTP integration test로 group+owner membership 원자성, actor-scoped 목록, 권한·삭제 cascade와 개인 Snap 보존을 먼저 실패시킨다.
- TDD Red 3: canonical OpenAPI example과 Swift API fixture가 exact field set·error mapping에서 먼저 실패하게 한다.
- TDD Red 4: injected group client를 쓰는 iOS model test와 DEBUG fixture XCUITest로 empty→create→list와 owner delete 흐름을 먼저 실패시킨다.
- visual seam: Figma node별 reference/app/overlay/diff/report를 393x852로 만들며 Figma에 없는 화면의 임의 pixel parity를 주장하지 않는다.
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
- 결과: `proposed`; `WORK-026` 완료 뒤 Red부터 기록
- 리뷰: 2026-08-13 사용자가 전체 MVP를 단계별 TDD·통합·visual 검증과 기능별 commit으로 계속 진행하도록 승인함

## Agent rules impact

- 영향 여부: yes
- 근거: 첫 group persistence/API와 iOS 그룹 탭이 실제 완료되면 현재 단계·검증 근거가 바뀐다. 장기 group 불변 규칙은 이미 `AGENTS.md`에 반영되어 있다.
- 처리 결과: 구현 완료 시 canonical 문서와 대조하고 `AGENTS.md` 현재 단계·실제 검증 증거만 동기화한다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: stage 시작 SHA를 고정 base로 한 incremental update
- base: `WORK-027` 구현 시작 시 고정
- risk: high (authorization, Unicode validation, transaction, destructive group lifecycle)
- findings와 처리 결과: 서버·iOS의 의미 있는 변경 묶음마다 standard detail로 검사하고 actionable finding은 TDD 수정·전체 회귀·재update한다.

## Decisions and risks

- 2026-08-13 사용자 승인을 기록하되 의존 작업 완료 전까지 상태는 `proposed`로 유지한다.
- `depends_on: [WORK-026]`은 사용자가 요구한 Stage 6 완전 통과 후 Stage 7 착수라는 delivery-order gate다. group 생성·목록의 compile/schema가 media·multi-photo 구현에 직접 의존하는 것은 아니며, 구현에서는 identity·personal Snap의 기존 경계만 사용한다.
- `snap_shares`가 아직 없는 Stage 7에서 미래 cascade 성공을 주장하지 않는다. group/member/account lifecycle의 share 정리는 `WORK-029` schema 도입 뒤 `WORK-029`, projection 잔존 여부는 `WORK-030`이 회귀 검증한다.
- 이름은 표시값이지 식별자가 아니므로 중복 방지용 조회·constraint를 만들지 않는다.
- amount visibility migration·변경 endpoint를 선행 구현하지 않는다.
- group 삭제는 공유 관계의 lifecycle이며 개인 Snap 소유권을 침범하지 않는다.

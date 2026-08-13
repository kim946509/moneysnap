---
id: WORK-029
status: proposed
depends_on: [WORK-028]
owner: codex
---

# Stage 8 개인 Snap 단일-group 공유 command

## Intent

사용자가 이미 durable save된 자신의 개인 Snap을 Home의 명시적 action으로 한 번에 한 group에 공유하고, 취소·실패·재시도에도 개인 기록과 공유 멱등성을 지킨다.

## In scope

- personal Snap과 group을 잇는 `snap_shares` persistence·unique constraint와 별도 share mutation ledger
- 한 Snap→한 group의 authenticated share API와 OpenAPI contract
- Snap owner, current membership, deleted group/Snap 권한 검사와 same Snap/group idempotency
- 개인 save와 분리된 `clientMutationId`, commit-unknown retry·concurrency·conflict 처리
- iOS Home share action, 단일-group 선택 sheet, visibility 안내, cancel/failure/retry/success state
- 같은 Snap을 다른 group에 공유할 때 group마다 action을 다시 실행하는 흐름
- `snap_shares` 도입 뒤 `WORK-027`, `WORK-028`의 group/member/account lifecycle cascade 회귀
- 서버 단위·HTTP/PostgreSQL integration, Swift model/API, XCUITest와 Figma 393x852 visual 검증

## Out of scope

- 개인 Snap record command 안의 group 선택 또는 자동 공유
- multi-Snap·multi-group batch, 기본 공유 group, 공개 피드와 전체 공개
- group visible/hidden Today projection과 대표 Snap layout; `WORK-030`이 소유한다.
- 공유 group 변경 UI, share 복제본, comment·like·notification
- live Neon/R2 배포와 외부 인프라 변경

## Acceptance criteria

- [ ] share command는 이미 commit된 durable personal Snap ID, 현재 membership의 group ID와 record 때 사용하지 않은 별도 `clientMutationId` 하나만 의미 입력으로 받는다.
- [ ] command는 Snap 1개와 group 1개만 처리하고 array·multi-select·batch field와 visibility override를 받지 않는다.
- [ ] actor는 Snap owner이자 요청 시점의 active group member여야 하며, 비소유 Snap·비회원·삭제 group/Snap은 외부에서 구별되지 않는 `NOT_ACCESSIBLE`로 거부된다.
- [ ] 성공은 개인 Snap을 복제·이동하지 않고 `(snapId, groupId)` share 관계와 server `Clock`의 `sharedAt`만 만든다.
- [ ] 같은 actor·mutation ID·동일 payload replay는 최초 결과를 반환하고, 새 mutation ID로 동일 Snap·group을 반복 share해도 최초 share identity와 `sharedAt`을 그대로 반환해 대표 최신성을 갱신하지 않는 멱등 성공이다.
- [ ] 같은 actor·mutation ID의 다른 Snap/group payload는 최초 결과를 보존하고 `409 MUTATION_CONFLICT`와 `correlationId`를 반환한다.
- [ ] 같은 Snap/group에 대한 동시 요청은 share 하나만 만들며 모든 성공 response가 동일한 share identity/result를 가리킨다.
- [ ] mutation reservation 뒤 membership 재검사나 insert가 실패하면 reservation과 share가 함께 rollback되어 정상 retry를 막지 않는다.
- [ ] share 취소·sheet dismiss·client transport 실패·server 4xx/5xx는 이미 저장된 개인 Snap을 수정·삭제·rollback하지 않는다.
- [ ] group 탈퇴·제거·삭제는 관련 share 관계를 제거해 projection 접근을 막지만 개인 Snap은 보존한다.
- [ ] 개인 Snap 삭제는 관련 share 관계를 함께 제거하고 이후 share/retry를 `NOT_ACCESSIBLE`로 처리한다.
- [ ] owner 계정 탈퇴는 owned group의 share를 먼저 삭제한 뒤 owner 개인 Snap을 account cascade로 삭제하고, 그 group의 다른 member 개인 Snap은 보존한다.
- [ ] member 계정 탈퇴는 그 member의 share·membership과 개인 계정 데이터를 삭제하되 group 및 다른 actor의 개인 Snap을 보존한다.
- [ ] `WORK-027`, `WORK-028`에서 이미 통과한 group delete, self-leave, owner removal과 owner/member account deletion fixture를 `snap_shares` migration 이후 다시 실행해 dangling share가 남지 않음을 증명한다.
- [ ] bearer 없음·만료·폐기 session은 canonical `401 SESSION_REJECTED`, 입력 오류·conflict·접근 거부·server 실패는 stable code와 correlation ID로 정규화된다.
- [ ] success response와 OpenAPI/iOS fixture에는 필요한 opaque share result만 있고 group visibility를 변경하거나 다른 member의 개인 데이터·금액을 노출하는 field가 없다.
- [ ] iOS Home은 actor가 속한 group이 하나 이상일 때만 durable personal Snap에 share action을 표시하고 record bottom sheet 안에는 group 선택을 넣지 않는다.
- [ ] share sheet는 현재 Snap 한 건과 group 한 곳만 선택하며 각 group의 immutable 공개/비공개 의미를 짧게 표시하되 visibility toggle을 제공하지 않는다.
- [ ] sheet skip·cancel은 network command를 보내지 않고 개인 Snap을 그대로 유지한다.
- [ ] submit 순간 share command를 불변으로 고정하고 duplicate tap을 막으며 commit-unknown 오류는 같은 mutation ID로만 명시적 재시도한다.
- [ ] 실패는 Home의 같은 Snap에서 재시도할 수 있고 성공한 share를 실패나 취소로 되돌리지 않으며, 자동으로 새 mutation ID를 만들어 중복 share하지 않는다.
- [ ] 다른 group에도 공유하려면 사용자가 Home share action을 다시 열어 group마다 별도 command를 실행한다.
- [ ] XCUITest가 group 없음, cancel, single-group success, transient retry, permission loss와 same Snap의 두 group 순차 공유를 deterministic fixture로 검증한다.
- [ ] share action·group sheet·실패/retry/success 중 정확한 Figma frame node·reference·checksum이 canonical manifest에 고정된 상태만 393x852 threshold gate를 적용한다.
- [ ] exact Figma node/reference가 없는 보조 오류 상태는 XCUITest·accessibility 기능 evidence로 판정하되, 핵심 share action/sheet/success 화면 자체의 reference가 없으면 기능 green까지만 기록하고 작업은 `design-gated`로 남긴다. 핵심 reference를 확보해 manifest/diff를 통과하기 전에는 `done`으로 전환하지 않는다.
- [ ] VoiceOver가 대상 group·visibility·공유 상태를 읽고 모든 action이 44pt 이상 target, Dynamic Type와 reduce-motion 대체를 유지한다.

## Test seam

- TDD Red 1: share application test가 durable owner Snap·current membership·한 Snap→한 group·별도 mutation ID 규칙에서 먼저 실패한다.
- TDD Red 2: PostgreSQL 18 HTTP integration test가 unique relation, concurrent replay/conflict, rollback과 group/member/account/Snap lifecycle 보존을 먼저 실패시킨다.
- TDD Red 3: canonical OpenAPI example과 Swift URLProtocol fixture가 exact body/response/error 및 raw record/share mutation 분리에서 먼저 실패한다.
- TDD Red 4: injected clock/UUID/client를 쓰는 Swift model test가 immutable retry command, cancel no-call과 duplicate tap gate에서 먼저 실패한다.
- TDD Red 5: DEBUG fixture XCUITest가 Home action→단일 group sheet→share/retry와 개인 Snap 비rollback을 먼저 실패시킨다.
- visual seam: exact canonical Figma node/reference가 있는 상태만 393x852 reference/app/overlay/diff/report를 생성한다. 나머지는 기능 evidence와 디자인 precondition을 남기며 threshold 완화는 별도 하네스 승인 없이는 하지 않는다.
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
- 결과: `proposed`; `WORK-028` 완료 뒤 Red부터 기록
- 리뷰: 2026-08-13 사용자가 전체 MVP를 단계별 TDD·통합·visual 검증과 기능별 commit으로 계속 진행하도록 승인함

## Agent rules impact

- 영향 여부: yes
- 근거: 개인 우선 저장과 명시적 공유의 핵심 MVP loop가 실제 server/iOS 기능으로 완성되면 현재 단계·검증 근거가 바뀐다.
- 처리 결과: 구현 완료 시 canonical 정책과 `AGENTS.md`의 record/share 분리 불변 규칙을 대조하고 현재 단계·증거만 동기화한다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: stage 시작 SHA를 고정 base로 한 incremental update
- base: `WORK-029` 구현 시작 시 고정
- risk: high (owner authorization, membership TOCTOU, idempotency, personal-data preservation)
- findings와 처리 결과: schema/application/HTTP와 iOS state 변경 묶음마다 standard detail로 검사하고 finding은 TDD 수정·전체 회귀·재update한다.

## Decisions and risks

- 2026-08-13 사용자 승인을 기록하되 의존 작업 완료 전까지 상태는 `proposed`로 유지한다.
- `depends_on: [WORK-028]`은 group membership·lifecycle API라는 실제 code/schema 의존이면서 사용자의 Stage 7 완전 통과 후 Stage 8 착수 gate다.
- `snap_shares`를 처음 도입하는 이 작업이 Stage 7 lifecycle의 share cascade를 소유한다. 이전 Stage 7 완료 증거만 인용하지 않고 migration 이후 같은 삭제·탈퇴·제거·계정 탈퇴 회귀를 다시 실행한다.
- 공유는 개인 Snap의 복제나 상태 전환이 아니라 별도 relation이다.
- record와 share를 하나의 transaction처럼 가장하지 않고, 공유 실패는 durable personal save의 성공을 되돌리지 않는다.
- batch abstraction·outbox·event bus를 선행 도입하지 않고 PostgreSQL transaction과 concrete group application command로 닫는다.

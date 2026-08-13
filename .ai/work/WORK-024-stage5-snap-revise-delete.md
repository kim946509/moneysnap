---
id: WORK-024
status: proposed
depends_on: [WORK-023]
owner: codex
---

# Stage 5 개인 Snap 상세·수정·삭제

## Intent

로그인한 사용자가 자신의 Snap 상세를 확인하고 카테고리·금액만 안전하게 수정하거나 명시적 확인 뒤 삭제하며 Home에서 즉시 일관된 결과를 본다.

## In scope

- `GET /api/v1/snaps/{snapId}` (`getSnap`)
- `PATCH /api/v1/snaps/{snapId}` (`reviseSnap`)와 category·amount·`expectedVersion`·`clientMutationId`
- `DELETE /api/v1/snaps/{snapId}` (`deleteSnap`)와 required `X-Client-Mutation-Id` header
- owner scope, `NOT_ACCESSIBLE`, optimistic version, revise/delete mutation replay
- source Snap hard delete와 현재 개인 projection의 즉시 제거; 후속 share projection이 원본을 복제하지 않는 삭제 계약
- canonical OpenAPI examples와 Spring provider/iOS consumer contract
- Home 목록→Snap 상세, category/amount edit, delete confirmation와 오류 복구
- 서버/iOS unit·PostgreSQL/HTTP integration·XCUITest·Figma `77:582` visual gate

## Out of scope

- `localDay`, 사진, 공유 그룹·공개 설정 수정
- image 교체·R2 object cleanup 구현; Stage 6에서 추가
- group share schema/UI; Stage 8에서 source deletion cascade regression을 추가
- 과거 목록·보관함 pagination
- undo/휴지통·soft delete·revision history·multi-device realtime push
- server 배포와 live Neon 호출

## Acceptance criteria

- [ ] owner가 `GET /api/v1/snaps/{snapId}`를 호출하면 정확히 `id`, `category`, `amountWon`, immutable `localDay`, `createdAt`, `updatedAt`, 양의 `version`을 `200`으로 받는다.
- [ ] 다른 actor의 ID와 존재하지 않는 ID는 동일한 status·error code·body schema인 `404 NOT_ACCESSIBLE`와 `correlationId`를 반환한다.
- [ ] bearer가 없거나 만료·폐기된 detail/revise/delete는 `401 SESSION_REJECTED`이고 resource 존재 여부를 드러내지 않는다.
- [ ] `PATCH` body는 정확히 `clientMutationId`, `expectedVersion`, `category`, `amountWon`만 받으며 금액은 `1...999,999,999`; `localDay`, image, owner, group, visibility와 unknown property는 `400 INVALID_REQUEST`로 거부된다.
- [ ] 정상 revise는 owner row의 category·amount만 원자적으로 바꾸고 `localDay`·`createdAt`을 보존하며 `updatedAt`, `version = expectedVersion + 1`의 representation을 `200`으로 반환한다.
- [ ] 같은 actor·mutation ID·동일 normalized revise payload replay는 후속 version 검사보다 먼저 최초 response를 반환하고, 같은 key의 다른 payload는 원본을 보존한 채 `409 MUTATION_CONFLICT`다.
- [ ] owner의 현재 version이 `expectedVersion`과 다르면 덮어쓰지 않고 `409 SNAP_VERSION_CONFLICT`와 `correlationId`를 반환하며 최신 값을 response에 섞어 유출하지 않는다.
- [ ] 동시 같은-version revise 두 건은 최대 한 건만 성공하고 나머지는 version conflict이며 partial field update나 lost update가 없다.
- [ ] owner가 새 `X-Client-Mutation-Id`로 `DELETE`하면 `204`이고 source row와 현재 Today/detail projection에서 응답 전에 사라진다.
- [ ] 같은 actor·mutation ID·같은 Snap delete replay는 source가 이미 없어도 `204`; 같은 key를 다른 Snap에 쓰면 `409 MUTATION_CONFLICT`; 새 key의 unknown/foreign ID는 `404 NOT_ACCESSIBLE`다.
- [ ] delete와 revise가 경합하면 row/transaction 순서가 결과를 직렬화한다. revise가 먼저 commit되면 뒤의 delete도 최신 row를 삭제할 수 있고, delete가 먼저 commit되면 revise는 `NOT_ACCESSIBLE`로 실패하며, 어떤 순서에서도 삭제 뒤 resurrection·partial update·stale projection이 없다.
- [ ] 예상한 persistence 실패는 mutation·Snap을 함께 rollback하고 stack trace·SQL·payload 없이 `500 INTERNAL_ERROR`와 `correlationId`만 반환해 같은 semantic mutation을 안전하게 재시도할 수 있다.
- [ ] Stage 8의 `snap_shares`는 source Snap FK/cascade 또는 source join으로 삭제를 즉시 반영해야 하며, Stage 8가 shared projection 삭제 regression을 추가하기 전에는 이 항목이 존재하지 않는 group schema를 선도입하지 않는다.
- [ ] OpenAPI가 세 operation, path UUID, revise body, delete header, `200/204/400/401/404/409/500`과 exact examples를 소유하고 Spring provider/iOS consumer가 같은 `contracts/examples/v1/snaps/**` wire shape를 검증한다.
- [ ] Home의 오늘 소비 항목을 누르면 상세를 서버에서 조회하고, read-only day와 category·amount를 보여주며 사진 없는 Snap에는 category별 고정 placeholder를 사용한다.
- [ ] 편집 UI는 category·amount만 제공하고 original version을 제출한다. 성공하면 상세와 Home의 해당 항목·합계를 즉시 한 번 갱신한 뒤 canonical Today refresh로 확인한다.
- [ ] version conflict는 사용자의 입력을 성공으로 가장하지 않고 최신 detail을 다시 불러올 선택을 제공하며, `NOT_ACCESSIBLE`는 stale 상세를 닫고 Home을 refresh한다.
- [ ] 삭제는 영향을 명확히 설명하는 위험 확인을 거친 뒤에만 전송하고, 성공하면 상세를 닫고 Home 캔버스·목록·합계에서 즉시 제거한다.
- [ ] revise/delete의 transient·5xx·malformed-response commit-unknown 상태는 같은 mutation ID로만 재시도하고 임의 새 mutation을 만들어 중복 실행하지 않으며 취소·실패 때 성공 UI를 표시하지 않는다.
- [ ] 상세 loading/error retry, edit validation, saving/deleting lock, delete confirmation과 recovery action은 44pt target, VoiceOver label·focus/announcement와 Dynamic Type을 유지한다.
- [ ] 상세·편집 중 exact source가 확인된 상태만 Figma node `77:582`의 393x852 reference·checksum과 bounded threshold를 통과한다. 별도 source가 확인되지 않은 삭제 확인·오류 상태는 XCUITest·accessibility 기능 evidence와 design precondition으로 판정하며 임의 pixel parity를 주장하지 않는다.

## Test seam

- server rule seam: `KrwAmount`, category, version transition과 normalized revise/delete fingerprint를 순수 단위 테스트로 먼저 실패시킨다.
- server HTTP seam: `SnapRevisionHttpIntegrationTests`가 실제 PostgreSQL+Flyway에서 detail owner isolation, exact mutation, replay/conflict, concurrent version update, delete replay, rollback과 Today removal을 검증한다.
- authorization seam: foreign UUID와 random UUID의 detail/revise/delete response exact equality를 검증하고 내부 lookup 차이를 controller error로 노출하지 않는다.
- contract seam: WORK-022 canonical examples를 OpenAPI validator, MockMvc provider와 Swift consumer decoder가 함께 사용한다.
- iOS model seam: controllable client로 detail loading, edit draft, validation, immutable retry command, version conflict refresh, delete confirmation와 Home projection update를 검증한다.
- iOS transport seam: serialized URLProtocol로 exact method/path/body/header, bearer와 `200/204/400/401/404/409/500` normalization을 검증한다.
- UI seam: WORK-020 fixture provider와 XCUITest로 Home→detail→edit→Home, conflict recovery, delete cancel, confirmed delete→Home removal을 검증한다.
- visual seam: Figma `77:582`와 manifest의 detail scenario만 pixel gate에 추가하고 임의로 새 reference를 만들지 않는다.

## Verification

```text
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.snap.SnapRevisionRulesTests" --no-daemon --console=plain
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.snap.SnapRevisionHttpIntegrationTests" --no-daemon --console=plain
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.contract.OpenApiContractTests" --no-daemon --console=plain
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
git diff --check

# 기능 구현을 모두 닫은 뒤에만 오래 걸리는 전체 gate를 실행한다.
cd server; .\gradlew.bat test --no-daemon --console=plain
cd server; .\gradlew.bat bootJar --no-daemon --console=plain
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
bash ios/scripts/test.sh
bash ios/scripts/capture-visual-baseline.sh
```

## Evidence

- 실행 명령:
  - 2026-08-13 사용자: Stage 4·5 후속 작업 항목과 제시된 기본 경계를 모두 승인
- 결과: 구현 전 proposed; WORK-023 완료 뒤 Red부터 실행
- 리뷰: mutable field, optimistic concurrency, deletion replay와 recovery를 이 항목에 고정함

## Agent rules impact

- 영향 여부: yes
- 근거: Snap detail/revise/delete public interface와 source deletion·concurrency 불변 규칙이 추가되고 현재 MVP 단계가 이동한다.
- 처리 결과: 구현 완료 시 기준 문서와 Stage 8 삭제 인계 계약을 먼저 갱신한 뒤 `AGENTS.md`의 아키텍처 요약·현재 단계·검증 근거를 동기화한다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: 유효 graph 확인 후 Stage 5 시작 SHA 기준 incremental update
- base: Stage 5 시작 시 고정
- risk: high (owner authorization, money mutation, lost update, idempotent deletion, projection consistency)
- findings와 처리 결과: 서버·iOS 변경 묶음마다 standard detail로 검사하고 authorization·transaction·consumer gap은 TDD 수정 후 재update하며 전체 gate 전 최종 검사한다.

## Decisions and risks

- 수정은 자유 형식 PATCH가 아니라 두 mutable field의 complete replacement와 `expectedVersion`을 사용해 interface를 작게 유지한다.
- revise와 delete는 commit-unknown retry를 위해 actor-scoped mutation ledger를 재사용하되 범용 event sourcing이나 audit framework를 만들지 않는다.
- `NOT_ACCESSIBLE`은 foreign과 unknown을 같은 외부 결과로 정규화한다. 성공 mutation replay만 resource가 사라진 뒤에도 ledger에서 먼저 판정한다.
- 삭제는 source Snap hard delete다. Home·향후 group projection은 원본 row를 참조하고 별도 Snap 복제본을 만들지 않아 성공 응답 전에 사라진다.
- Stage 5에서는 아직 없는 media/group schema와 cleanup worker를 미리 만들지 않는다. Stage 6·8이 FK/cleanup을 추가할 때 이 삭제 계약의 통합 회귀를 각자 소유한다.

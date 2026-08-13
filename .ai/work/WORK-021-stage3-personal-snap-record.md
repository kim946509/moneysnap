---
id: WORK-021
status: active
depends_on: [WORK-017, WORK-019, WORK-020, WORK-022]
owner: codex
---

# Stage 3 사진 없는 개인 Snap 저장

## Intent

로그인한 사용자가 Home에서 사진 없이 카테고리와 금액을 입력해 자신의 개인 Snap 한 건을 멱등하게 저장하고 즉시 Home에서 확인한다.

## In scope

- authenticated actor의 `userId`만 feature-neutral principal로 노출
- canonical API error envelope를 identity와 snap 두 feature가 공유하도록 최소 이동
- Flyway `V4` 개인 Snap schema와 owner-scoped record idempotency
- `POST /api/v1/snaps`와 OpenAPI request·response·error contract
- 서버 Clock·tzdb region `ZoneId`/`UTC` 기반 local day 검증
- iOS authenticated HTTP transport와 Snap record URLSession adapter
- Home `기록하기`와 중앙 `추가` action, no-photo category→amount bottom-sheet flow
- 금액 keypad, retry, duplicate-submit gate, 저장 성공의 즉시 Home 반영
- unit·HTTP/PostgreSQL integration·Swift model/API·XCUITest·393x852 visual 검증

## Out of scope

- camera, PhotosUI, image normalization, R2와 `ImageRef`; Stage 6에서 추가
- 실제 Today 재조회와 relaunch 동기화; Stage 4에서 추가
- Snap 상세·수정·삭제, group·share·archive
- 서버 배포와 live Neon·R2 호출
- Figma에 없는 no-photo 전체 화면을 임의 baseline으로 만드는 일

## Acceptance criteria

- [ ] bearer user가 `1...128`자 nonblank opaque `clientMutationId`, `localDay`, tzdb region `timeZone`, `category`, `amountWon`을 보내면 `201`, stable Snap ID, 같은 ID의 `Location`과 정확한 개인 Snap representation을 받는다. iOS는 새 command에 UUID 문자열을 쓰지만 server는 UUID 형식을 요구하지 않는다.
- [ ] response에는 `ownerId`, `sessionId`, `groupId`, `visibility`, raw token 또는 아직 존재하지 않는 image URL이 포함되지 않는다.
- [ ] 금액은 `1...999,999,999`, category는 확정 enum, time zone은 tzdb available region ID 또는 `UTC`이고, 날짜는 그 zone에서 server current day 또는 직전 day일 때만 저장된다.
- [ ] numeric offset·timezone short alias·미래·2일 이전·malformed body는 `400 INVALID_REQUEST`와 `correlationId`로 거부되고 어떤 Snap도 만들지 않는다.
- [ ] 저장된 `localDay`는 이후 revise·share·조회 시 재계산하거나 바꾸지 않는 소유자 calendar label이다.
- [ ] request가 `ownerId`, `groupId`, `visibility`, `imageId` 또는 정의되지 않은 property를 포함하면 무시하지 않고 `400 INVALID_REQUEST`로 거부한다.
- [ ] 같은 actor·mutation ID·동일 normalized payload는 최초 결과를 반환하며, 이 replay는 자정 이후 dynamic 날짜 검증보다 먼저 처리된다.
- [ ] 같은 actor·mutation ID의 다른 payload는 최초 결과를 보존하고 `409 MUTATION_CONFLICT`와 `correlationId`를 반환한다.
- [ ] 서로 다른 actor는 같은 mutation ID를 독립적으로 사용할 수 있고, 같은 actor의 동시 동일 요청은 하나의 Snap ID만 만든다.
- [ ] 같은 actor·mutation ID의 서로 다른 payload 동시 요청은 하나만 `201`이고 다른 하나는 `409`이며 최초 Snap만 남는다.
- [ ] mutation reservation 뒤 날짜 validation 또는 DB insert가 실패하면 reservation과 Snap이 함께 rollback되고 같은 key의 올바른 retry가 성공한다.
- [ ] bearer가 없거나 만료·폐기된 경우 canonical `401 SESSION_REJECTED`를 반환한다.
- [ ] 예상한 persistence 실패는 stack trace·SQL·payload 없이 `500 INTERNAL_ERROR`와 correlation ID만 반환한다.
- [ ] V4는 이전 JAR이 무시할 수 있는 expand-only migration이고 계정 삭제는 해당 owner의 Snap을 cascade 삭제한다.
- [ ] iOS는 요청 직전에 AuthenticationModel에서 access token을 얻고, 늦게 도착한 이전 token의 401이 회전된 현재 session을 지우지 않는다.
- [ ] Home `기록하기`와 중앙 `추가`는 persistent `.add` tab을 선택하지 않고 같은 no-photo capture flow를 연다.
- [ ] category를 선택해야 amount 단계로 이동하며 뒤로 가기 시 현재 draft를 보존한다.
- [ ] keypad는 digit buffer에서 `₩18,900` 같은 KRW 표시를 만들고 leading zero·빈 값·0·상한 초과를 저장하지 않으며 모든 action이 44pt 이상 target과 VoiceOver label·trait를 가진다.
- [ ] 첫 submit 순간 command를 불변으로 고정하고 transient·5xx·malformed-response 같은 commit-unknown 실패는 동일 command·mutation ID로만 재시도하며 중복 tap과 swipe dismiss를 막고, 명시적 포기는 저장됐을 가능성을 안내한 확인 뒤에만 허용한다.
- [ ] `409 MUTATION_CONFLICT`는 correlation ID를 보존한 비재시도 오류로 표시하고 자동으로 새 mutation ID를 만들어 중복 저장하지 않는다.
- [ ] `400` 입력 오류, `401` session rejection, `409` conflict, `5xx`·transport 재시도 오류, malformed response의 결과 불명을 서로 다른 client error로 정규화한다.
- [ ] 성공 receipt는 sheet를 닫고 같은 session의 Home에 즉시 한 번만 반영되며, 실패·취소는 저장된 것처럼 표시하지 않는다.
- [ ] 단계 전환은 VoiceOver focus·announcement와 Dynamic Type에서도 category, amount, retry action을 잃지 않는다.
- [ ] category·amount sheet와 Home 복귀는 승인된 Figma node/reference 및 기존 bounded threshold를 통과한다.

## Test seam

- server rules seam: `KrwAmount`, category, tzdb region/UTC local-day와 normalized command fingerprint를 순수 단위 테스트로 먼저 실패시킨다.
- server HTTP seam: 실제 PostgreSQL 18+Flyway와 bearer fixture를 쓰는 `SnapRecordHttpIntegrationTests`가 response, owner scope, replay/conflict, concurrency와 rollback-visible behavior를 검증한다.
- rollback seam: Testcontainers DB에 테스트 동안만 failing trigger를 설치해 reservation 이후 insert 실패를 만들고, transaction rollback과 같은 request retry를 HTTP로 검증한 뒤 trigger를 제거한다.
- persistence shape는 HTTP 결과로 검증하고 raw table count는 동시 단일 생성·account cascade 같은 DB contract에 필요한 테스트로만 제한한다.
- iOS model seam: recording spy와 injected clock/timezone/UUID로 phase, digit buffer, immutable retry command, duplicate gate와 receipt를 검증한다.
- iOS transport seam: serialized URLProtocol로 bearer, JSON body, `201/400/401/409/5xx`, fractional-independent date decoding과 stale-401 처리를 검증한다.
- UI seam: WORK-020의 DEBUG fixture와 XCUITest로 Home/add→category→amount→save→Home 흐름을 검증한다.
- visual seam: exact Figma category·amount component/reference가 확보된 scenario만 393x852 evidence로 완료 처리한다.

## Verification

```text
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.snap.*RulesTests" --no-daemon --console=plain
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.snap.SnapRecordHttpIntegrationTests" --no-daemon --console=plain
cd server; .\gradlew.bat test --no-daemon --console=plain
cd server; .\gradlew.bat bootJar --no-daemon --console=plain
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
bash ios/scripts/test.sh
bash ios/scripts/capture-visual-baseline.sh
git diff --check
```

## Evidence

- 실행 명령:
  - dependency status와 `git status --short` 확인
- 결과:
  - WORK-017·019·020·022가 모두 완료됐고 working tree가 clean인 `3fa01c9`를 Stage 3 시작 기준점으로 고정했다.
- 리뷰: 2026-08-13 사용자가 전체 MVP와 하네스 변경을 명시 승인했으며 Red부터 구현을 시작한다.

## Agent rules impact

- 영향 여부: yes
- 근거: 첫 authenticated product API, 개인 Snap persistence와 실제 iOS record flow가 현재 단계·검증 설명을 바꾼다.
- 처리 결과: 기준 문서를 먼저 갱신한 뒤 완료 시 `AGENTS.md` 현재 단계와 검증 근거를 동기화한다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: valid graph 확인 후 stage-start SHA `3fa01c9` 기준 incremental update 예정
- base: `3fa01c9`
- risk: high (owner authorization, money, idempotency, transaction, session boundary)
- findings와 처리 결과: 각 의미 있는 서버/iOS 변경 묶음 뒤 standard detail로 검사하고 actionable finding은 TDD 수정·재update한다.

## Decisions and risks

- Java는 실제 사용 사례인 concrete `SnapJournal`이 `JdbcClient`, `TransactionTemplate`, `Clock`을 직접 감싸며 별도 `SnapStore` interface·adapter·clock provider를 만들지 않는다.
- Spring principal은 identity 내부 session ID를 노출하지 않는 immutable authenticated-user value로 제한한다.
- iOS authenticated transport는 concrete type과 injected closures/URLSession으로 검증하고 한 구현뿐인 protocol·factory를 추가하지 않는다.
- record command에는 group·visibility·raw image·R2 URL을 넣지 않는다.
- V4의 `snap_record_mutations`는 actor-scoped concrete ledger이며 범용 mutation framework를 만들지 않고 PostgreSQL unique key로 동일 key 요청을 직렬화한다.
- transaction은 semantic request의 versioned SHA-256 fingerprint로 mutation reservation을 먼저 claim하고, 기존 row면 replay/conflict를 반환하며, 신규 row일 때만 dynamic local-day를 검증하고 Snap을 insert한 뒤 함께 commit한다.
- Stage 3의 session-local Home 반영은 durable server save 성공 receipt만 사용하며 Stage 4가 canonical Today GET과 relaunch 동기화를 대체한다.
- production AppShell은 Figma Home fixture를 기록 API의 성공 데이터로 가장하지 않으며 `TodaySnapViewModel.apply(_:)`가 201 receipt를 한 번만 반영한다.
- exact no-photo full-screen Figma frame이 없으면 component-level evidence와 기능 XCUITest까지만 기록하고 pixel parity를 허위로 완료 처리하지 않는다.

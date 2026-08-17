---
id: WORK-023
status: verify
depends_on: [WORK-021]
owner: codex
---

# Stage 4 오늘 개인 Snap 재조회

## Intent

로그인한 사용자가 저장한 오늘의 개인 Snap을 서버의 canonical 조회로 다시 불러와 새로고침과 앱 재실행 뒤에도 정확한 Home을 본다.

## In scope

- `GET /api/v1/snaps/today?timeZone={tzdb-region-or-UTC}`와 `getTodaySnaps` OpenAPI operation
- authenticated actor owner scope와 저장된 immutable `localDay` 기준 조회
- canonical Today success·empty·error example과 Spring provider/iOS consumer contract
- 실제 PostgreSQL 18에서 owner·day·stable order·합계 조회
- production `SnapJournalClient.today` URLSession adapter와 authenticated transport 연결
- 초기 loading, empty, blocking error+retry, content refresh와 nonblocking refresh failure
- Stage 3 record receipt 직후 canonical Today refresh와 앱 재실행 재조회
- Home XCUITest와 Figma Home `9:2` 393x852 visual evidence

## Out of scope

- 과거 날짜·기간·pagination 조회와 보관함; Stage 9에서 추가
- Snap 상세·수정·삭제; Stage 5에서 추가
- 사진 read grant, group·share projection
- offline cache·background sync·push refresh
- server 배포와 live Neon 호출
- Figma reference가 없는 empty/error 화면을 임의 pixel baseline으로 승인하는 일

## Acceptance criteria

- [ ] bearer user가 `GET /api/v1/snaps/today?timeZone=Asia%2FSeoul`을 호출하면 서버 `Clock`의 instant를 해당 zone으로 변환한 `localDay`, `totalAmountWon`, `snaps`를 `200`으로 받는다.
- [ ] `timeZone`은 tzdb available region ID 또는 `UTC`만 허용하며 누락·numeric offset·short alias·unknown ID는 Snap 정보 없이 `400 INVALID_REQUEST`와 `correlationId`로 거부된다.
- [ ] 조회는 authenticated actor의 `owner_id`와 server가 계산한 오늘 `localDay`를 함께 조건으로 사용하고, `createdAt`이나 조회 시점 zone으로 각 Snap의 day를 재계산하지 않는다.
- [ ] 같은 날짜의 다른 actor Snap, 직전 day Snap과 미래 fixture는 response·합계에 포함되지 않고 다른 actor의 존재 여부도 드러내지 않는다.
- [ ] 결과는 `createdAt` 내림차순, 동률이면 `id` 내림차순의 stable order이며 `totalAmountWon`은 반환된 모든 amount의 overflow-safe 합계다.
- [ ] 기록이 없으면 `404/204`가 아니라 같은 schema의 `200`, 정확한 요청 day, `totalAmountWon: 0`, 빈 `snaps`를 반환한다.
- [ ] 각 Snap representation은 정확히 `id`, `category`, `amountWon`, `localDay`, `createdAt`을 포함하고 `ownerId`, `sessionId`, `groupId`, `visibility`, token 또는 permanent image URL을 포함하지 않는다.
- [ ] bearer가 없거나 만료·폐기되면 canonical `401 SESSION_REJECTED`, 예상한 persistence 실패는 내부 정보 없이 `500 INTERNAL_ERROR`와 `correlationId`를 반환한다.
- [ ] `contracts/openapi/moneysnap-v1.yaml`과 `contracts/examples/v1/snaps/**`가 Today request parameter, success, empty와 모든 error wire shape를 소유한다.
- [ ] Spring MockMvc provider test의 status·header·exact field set과 iOS consumer test의 실제 canonical JSON decode가 WORK-022 contract gate와 함께 통과한다.
- [ ] production AppShell은 Figma fixture 대신 authenticated URLSession adapter를 주입하고 유효한 session 복구 뒤 현재 device tzdb region으로 Today를 요청한다.
- [ ] 초기 요청 중에는 loading, 빈 결과에는 기록 action이 있는 empty, 최초 실패에는 retry 가능한 error를 표시하고 성공 content를 이미 가진 refresh 실패는 content를 지우지 않고 재시도 가능한 비차단 상태로 남긴다.
- [ ] 동시에 겹친 load/refresh에서 이전 session·이전 local day의 늦은 response가 더 최신 Home state를 덮어쓰지 않는다.
- [ ] Stage 3 record 성공 receipt는 즉시 한 번 반영한 뒤 같은 day Today를 refresh하고, canonical response가 receipt 중복 없이 최종 Home state를 대체한다.
- [ ] 앱 process를 종료·재실행한 authenticated XCUITest는 매 launch마다 같은 pre-seeded canonical Today provider를 통해 같은 record를 다시 표시하고, pull/retry refresh도 같은 stable 결과를 보인다. create 이후 실제 durable 재조회는 PostgreSQL HTTP integration test가 별도로 증명한다.
- [ ] loading/content/empty/error/record 후 refresh의 control과 상태 변화는 VoiceOver label·announcement, Dynamic Type와 44pt 이상 action target을 유지한다.
- [ ] Home content scenario는 Figma node `9:2`, 393x852 reference·checksum과 승인된 threshold를 통과하며 empty/error는 별도 source reference가 생기기 전 기능 evidence로만 판정한다.

## Test seam

- server query seam: concrete `SnapJournal.today(actor, zone)`를 fixed `Clock`과 실제 PostgreSQL adapter로 검증하고 별도 범용 query/repository interface를 만들지 않는다.
- server HTTP seam: `TodaySnapHttpIntegrationTests`가 owner/day isolation, immutable day, stable order, empty, amount sum, invalid zone, session과 persistence error를 MockMvc+Testcontainers로 먼저 실패시킨다.
- contract seam: WORK-022의 canonical examples를 OpenAPI validator, Spring provider exact JSON assertion과 Swift consumer decoder가 함께 읽는다.
- iOS model seam: controllable client와 suspended continuation으로 initial/empty/failure/refresh, stale response suppression, record receipt 후 canonical replacement를 검증한다.
- iOS transport seam: serialized URLProtocol로 bearer, percent-encoded `timeZone`, exact path/query와 `200/400/401/500` decoding을 검증한다.
- UI seam: WORK-020 DEBUG provider가 process relaunch에도 유지하는 deterministic Today fixture server를 사용해 launch→content, empty→record, failure→retry, record→refresh를 XCUITest한다.
- visual seam: Home `9:2`의 existing manifest/reference만 재사용하고 새 source node 없는 상태 화면을 허위 baseline으로 추가하지 않는다.

## Verification

```text
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.snap.TodaySnapHttpIntegrationTests" --no-daemon --console=plain
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
- 결과: 구현 전 proposed; WORK-021 완료 뒤 Red부터 실행
- 리뷰: exact endpoint와 provider/consumer owner를 이 항목에 고정함

## Agent rules impact

- 영향 여부: yes
- 근거: fixture 기반 Home을 authenticated persistent Today API로 교체하고 Stage 4 완료 상태·검증 근거를 바꾼다.
- 처리 결과: 구현 완료 시 canonical 문서를 먼저 갱신한 뒤 `AGENTS.md` 현재 단계와 실제 검증 결과를 동기화한다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: 유효 graph 확인 후 Stage 4 시작 SHA 기준 incremental update
- base: Stage 4 시작 시 고정
- risk: medium-high (owner authorization, calendar day, contract/provider/consumer drift, async stale state)
- findings와 처리 결과: 서버·iOS의 의미 있는 변경 묶음마다 standard detail로 검사하고 actionable finding은 TDD 수정·전체 gate 전 재update한다.

## Decisions and risks

- Today interface는 client가 날짜를 주장하게 하지 않고 `timeZone`만 받아 server `Clock`이 오늘을 정한다. 저장된 `localDay`는 재계산하지 않고 exact equality로 조회한다.
- Today response 한 벌이 total과 Snap 목록을 함께 소유해 client의 추가 합계 endpoint와 왕복을 만들지 않는다.
- server query는 한 구현뿐인 repository abstraction을 추가하지 않고 concrete `SnapJournal` 안에 owner/day predicate와 stable ordering을 숨긴다.
- Stage 3 receipt는 perceived latency만 줄이는 임시 state이며 Stage 4의 canonical GET이 durability와 relaunch truth를 소유한다.
- 오늘 전체 목록을 MVP에서 한 번에 반환한다. 실제 사용에서 응답 크기 문제가 확인되기 전 cursor와 별도 total endpoint를 선도입하지 않는다.

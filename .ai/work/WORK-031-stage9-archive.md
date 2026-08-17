---
id: WORK-031
status: proposed
depends_on: [WORK-030]
owner: codex
---

# Stage 9 보관함과 날짜별 개인 Snap 조회

## Intent

로그인한 사용자가 저장 당시의 날짜 의미를 잃지 않고 자신의 과거 Snap을 달력에서 찾아 안정적으로 페이지 이동하고 날짜별 상세를 확인한다.

## In scope

- owner 전용 `GET /api/v1/snaps/archive`와 OpenAPI request·response·error contract
- inclusive `fromLocalDay`·`toLocalDay`, bounded `limit`, opaque `cursor`를 사용하는 stable keyset pagination
- 저장된 `localDay DESC`, `createdAt DESC`, stable Snap ID DESC의 전체 정렬과 tie-break
- 저장 당시 immutable `localDay`를 기준으로 한 날짜 범위 조회와 기기 time zone 변경 경계
- Figma 보관함 달력 `77:681`, loading·failure·전체 빈 상태·선택 날짜 빈 상태
- 날짜별 개인 Snap 목록, 페이지 추가 로드와 기존 owner Snap 상세 진입
- server unit·PostgreSQL HTTP integration·OpenAPI·Swift model/API·XCUITest·393x852 visual 검증

## Out of scope

- 그룹에서 다른 member가 공유한 Snap, 공개 feed 또는 다른 사용자 archive
- 월간 지출 분석, 예산, 차트, 검색, tag·memo filter와 CSV/export
- 저장된 `localDay` 수정, 현재 기기 zone으로 과거 Snap relabeling, instant 기반 재계산
- archive에서 Snap 수정·삭제·공유를 중복 구현하는 일; 기존 Snap 상세 경계를 재사용한다.
- server deployment, live Neon·R2 호출과 Apple activation

## Acceptance criteria

- [ ] 유효한 bearer user만 자신의 nondeleted 개인 Snap을 조회하고, 다른 owner의 개인 Snap과 group share projection은 어떤 page에도 포함되지 않는다.
- [ ] `fromLocalDay`와 `toLocalDay`는 ISO `yyyy-MM-dd` inclusive 범위이고 `fromLocalDay <= toLocalDay`, 최대 42 calendar days여야 하며, 누락·malformed·역전·42일 초과는 `400 INVALID_REQUEST`와 `correlationId`로 거부된다.
- [ ] 조회는 저장된 `localDay`를 그대로 비교하며 time zone·numeric offset·instant 입력을 받지 않는다. 사용자가 기록 후 기기 time zone을 바꾸거나 DST 경계를 지나도 기존 Snap은 저장된 날짜에서 이동하지 않는다.
- [ ] 결과는 `localDay DESC`, `createdAt DESC`, Snap ID DESC로 완전 정렬되고 같은 timestamp·날짜가 있어도 순서가 결정론적이다.
- [ ] page `limit`은 기본 20, 허용 범위 `1...50`이고 첫 page 이후에는 offset이 아닌 opaque keyset cursor를 사용한다. cursor는 version과 기존 range·limit에 묶이며 malformed·다른 range/limit에 재사용한 cursor는 `400 INVALID_CURSOR`로 거부된다.
- [ ] page 1 뒤 더 최신 Snap이 추가되거나 기존 Snap의 amount/category가 수정돼도 같은 traversal의 후속 page에는 중복·건너뜀·재정렬이 생기지 않는다. 중간 삭제는 삭제된 행만 사라지고 이미 반환된 행을 다시 반환하지 않는다.
- [ ] `nextCursor`는 실제 후속 행이 있을 때만 존재하고 마지막 page에는 존재하지 않으며, 응답은 정의된 exact field 외 `ownerId`, `sessionId`, share/membership 또는 R2 credential을 노출하지 않는다.
- [ ] 요청한 bounded range의 `occupiedLocalDays`는 pagination과 분리된 owner-only distinct day summary로 첫 page에만 제공되어, 첫 page에 항목이 없는 날짜의 달력 marker도 정확하다. client는 같은 traversal 동안 이를 고정하고 명시적 refresh/new range에서만 새 summary로 교체한다.
- [ ] bearer가 없거나 만료·폐기된 경우 canonical `401 SESSION_REJECTED`를 반환하고 cursor·range의 존재 여부로 다른 owner 데이터의 유무를 추론할 수 없다.
- [ ] iOS archive model은 page별 응답을 stable Snap ID로 한 번만 병합하고, retry가 같은 cursor를 재사용하며 이전 성공 page를 지우지 않는다.
- [ ] 보관함은 Figma `77:681`의 월 달력에서 기록이 있는 날짜와 선택 날짜를 구분하고, 선택한 날짜의 개인 Snap만 날짜 상세에 표시한다.
- [ ] 개인 기록이 전혀 없는 전체 빈 상태와 기록은 있지만 선택 날짜가 비어 있는 상태가 서로 다른 설명·action을 제공하고, loading·retry 중 기존 content를 성공으로 가장하지 않는다.
- [ ] 날짜별 항목에서 기존 owner Snap 상세로 진입하며 detail에서 revise/delete 후 돌아오면 archive page와 날짜 marker가 중복 없이 갱신된다.
- [ ] 달력 날짜·이전/다음 월·항목·재시도 action은 VoiceOver label/trait와 44pt 이상 target을 가지며 Dynamic Type에서도 선택 날짜와 상세 진입을 잃지 않는다.
- [ ] exact source가 확인된 보관함 달력 상태만 Figma `77:681` 393x852 reference·threshold를 통과한다. 별도 source가 없는 empty/error/day-detail 상태는 XCUITest·accessibility 기능 evidence와 design precondition으로 판정하고 DEBUG fixture는 release build에 포함되지 않는다.

## Test seam

- TDD server seam: 저장된 `localDay` range, complete ordering tuple과 cursor encode/decode·filter binding을 순수 테스트에서 먼저 실패시킨다.
- authorization seam: 실제 PostgreSQL 18+Flyway와 두 owner, 공유 관계, 삭제 행 fixture를 사용해 owner-only exact response와 부정 권한을 HTTP에서 검증한다.
- pagination seam: 동일 날짜·동일 created-at 행, page 사이 insert/update/delete를 만들고 cursor traversal 전체의 stable ID sequence를 검증한다.
- timezone seam: Asia/Seoul·America/Los_Angeles·UTC와 DST 경계에서 기록 당시 `localDay`가 조회 zone 없이 같은 날짜에 남는지 검증한다.
- iOS seam: recording archive client와 URLProtocol fixture로 initial/load-more/retry/dedup/date selection/detail return 상태를 먼저 실패시킨다.
- UI·visual seam: WORK-020 하네스에 archive empty/content/day-detail scenario와 Figma `77:681` reference를 이 stage가 추가한다.
- 긴 회귀 테스트는 targeted red/green 동안 반복하지 않고 기능 AC가 모두 구현된 시점에 server 전체·bootJar·native UI·전체 visual suite를 한 번 실행한다.

## Verification

```text
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.snap.Archive*Tests" --no-daemon --console=plain
cd server; .\gradlew.bat test --no-daemon --console=plain
cd server; .\gradlew.bat bootJar --no-daemon --console=plain
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
bash ios/scripts/test.sh
bash ios/scripts/capture-visual-baseline.sh
git diff --check
```

## Evidence

- 실행 명령: 구현 전 canonical 문서·Figma node·선행 작업 계약 확인, 구현 후 위 명령 기록 예정
- 결과: 2026-08-13 작업 항목 작성 시점에는 계획만 고정했으며 runtime 완료를 주장하지 않음
- 리뷰: 사용자가 Stage 9~10을 포함한 후속 MVP 작업 진행을 포괄 승인함

## Agent rules impact

- 영향 여부: yes
- 근거: archive API, stable cursor와 immutable `localDay` 조회가 Snap 아키텍처 규칙·현재 단계·검증 범위를 확장한다.
- 처리 결과: 구현 시 canonical OpenAPI·아키텍처·화면 문서를 먼저 갱신하고 완료 후 `AGENTS.md` 현재 단계와 검증 설명을 동기화한다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: stage 시작 SHA를 고정 base로 한 incremental update
- base: WORK-031 구현 시작 시 고정
- risk: high (owner authorization, cursor correctness, date/timezone semantics, large history query)
- findings와 처리 결과: 서버와 iOS의 의미 있는 변경 묶음마다 standard detail로 검사하고 pagination·권한·테스트 공백은 같은 TDD loop에서 수정·재update한다.

## Decisions and risks

- pagination은 mutable amount/category가 아니라 immutable ordering tuple을 쓰며 범용 pagination framework를 만들지 않는다.
- API는 저장된 calendar label만 조회하고 archive request에서 time zone을 받아 과거 데이터를 다시 해석하지 않는다.
- visible calendar grid와 day detail은 같은 owner-only endpoint 계약을 사용하되 `occupiedLocalDays` summary와 paginated rows를 분리해 iOS가 전체 history를 한 번에 내려받지 않는다.
- 42일 범위와 기본 20/최대 50은 구현을 위한 bounded API guardrail이며 WORK-031 구현 시작 때 canonical ARCHITECTURE·OpenAPI에 먼저 동기화하고 contract tests로 고정한다. 제품 범위 변경이 아니라 운영상 조정 가능한 query limit으로 취급한다.
- Figma frame에 없는 day detail variation은 기존 Snap detail component를 재사용하고 임의 새 시각 기준선을 완료 증거로 만들지 않는다.

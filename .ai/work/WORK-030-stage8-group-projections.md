---
id: WORK-030
status: proposed
depends_on: [WORK-029]
owner: codex
---

# Stage 8 공개·비공개 그룹 Today projection

## Intent

현재 member가 그룹의 오늘 공유 흐름을 사람별 대표 Snap으로 보되, 비공개 그룹에서는 JSON과 UI 모두 금액 및 금액 추론 신호를 받지 않게 한다.

## In scope

- request `timeZone`·server `Clock`으로 계산한 today만 조회하는 group/member Today query, current membership authorization와 immutable `localDay` 보존
- amount-visible·amount-hidden 별도 server DTO/OpenAPI schema와 iOS typed projection
- member별 해당 날짜 최신 `sharedAt` 대표 Snap, Snap count와 member detail 진입
- 사진 없는 Snap의 category별 고정 icon/color placeholder와 profile fallback
- visible total/amount 표현과 hidden no-amount/no-total/no-amount-derived-size/order 부정 계약
- 그룹 탭 상세, Home group swipe와 member Today 상세의 SwiftUI state
- 서버 단위·HTTP/PostgreSQL integration, Swift decode/model, XCUITest와 Figma 393x852 visual 검증

## Out of scope

- 그룹 전체 가계부·정산·랭킹·통계, comment·like·realtime feed
- hidden amount를 client에 전달한 뒤 가리는 구현
- amount visibility 변경, 기록별 visibility override와 일부 공개
- 개인 Snap record/edit/delete 또는 share write command 변경
- 임의 과거 `localDay`/date 조회와 archive browsing; 별도 Stage 9 archive가 소유한다.
- 새 profile 사진·이름 편집, public image URL과 R2 credential
- live Neon/R2 배포와 외부 인프라 변경

## Acceptance criteria

- [ ] group Today/member Today query는 요청 시점 active membership을 확인하고 비회원·탈퇴/제거 member·삭제 group에는 다른 상태와 구별되지 않는 `NOT_ACCESSIBLE`을 반환한다.
- [ ] group Today/member Today request는 tzdb region `timeZone` 또는 `UTC`만 받고 server `Clock`의 current instant를 그 zone으로 변환해 계산한 today `localDay`만 조회한다.
- [ ] numeric offset·short alias·invalid zone은 `400 INVALID_REQUEST`로 거부하고, client가 임의 과거 `localDay`/date를 지정하는 field나 endpoint는 제공하지 않는다. 과거 조회는 Stage 9 archive 경계다.
- [ ] projection은 server가 계산한 today와 저장된 Snap의 immutable `localDay` label을 동등 비교하며, 저장 label을 조회 시점 zone으로 재계산하거나 변경하지 않는다.
- [ ] server와 OpenAPI는 amount-visible response와 amount-hidden response를 서로 다른 concrete schema/DTO로 정의하고 iOS도 별도 typed case로 decode한다.
- [ ] visible response는 공유 Snap의 amount와 member별 오늘 total을 명시적으로 제공할 수 있고, UI는 공개 그룹임을 표시한 뒤 그 total로 대표 오브젝트 크기를 표현할 수 있다.
- [ ] hidden response JSON의 어느 깊이에도 `amount`, `amountWon`, `total`, `totalAmount`, amount-derived `size`, `scale`, `rank`, `order` 또는 동등한 금액 추론 field가 존재하지 않는다.
- [ ] hidden server query/projection은 amount column을 DTO에 매핑하지 않고 array 순서도 금액과 무관한 deterministic membership order를 사용하며 별도 order field를 반환하지 않는다.
- [ ] hidden iOS model은 금액 property 자체를 가지지 않고 fixed size/amount-independent layout을 사용한다. Snap count를 쓰더라도 금액 기반 크기·색·정렬로 변환하지 않는다.
- [ ] raw MockMvc JSON negative assertion, OpenAPI schema negative fixture와 Swift decoding test가 hidden fixture에 금액·total·size/order field 하나를 추가하면 실패한다.
- [ ] 각 member의 대표 Snap은 server가 request `timeZone`으로 계산한 today `localDay`에 그 member가 해당 group에 공유한 항목 중 가장 최신 `sharedAt`을 사용하며 개인 최신 Snap이나 가장 비싼 Snap을 사용하지 않는다.
- [ ] 같은 `sharedAt` tie에서도 결정론적 opaque share identity로 같은 대표를 선택하고 amount를 tie-breaker로 사용하지 않는다.
- [ ] 대표/개별 공유 Snap에 active image가 없으면 category별로 고정된 동일 icon/color placeholder를 사용하고 같은 category의 amount에 따라 모양·크기·색을 바꾸지 않는다.
- [ ] image가 있으면 current membership뿐 아니라 그 `imageRef`가 requested group에 현재 공유된 Snap에 연결됐는지 함께 확인한 뒤 Stage 6 media authorization 경계로 short-lived read grant를 제공한다. 다른 개인 Snap이나 다른 group에만 공유된 image는 동일 `NOT_ACCESSIBLE`이며 permanent URL·R2 credential을 response에 넣지 않는다.
- [ ] 대표 오브젝트는 display name, 첫 grapheme 또는 MoneySnap mark avatar, 해당 날짜 Snap count와 member detail 진입을 제공한다.
- [ ] member Today detail은 그 member가 해당 group에 공유한 해당 날짜 Snap만 보여주며 visible/hidden schema 경계를 동일하게 유지한다.
- [ ] 개인 Snap 수정은 허용된 category/amount의 현재 값을 projection에 반영하고 삭제·group lifecycle로 share가 사라지면 다음 조회에서 즉시 제외된다.
- [ ] `WORK-027`, `WORK-028` lifecycle을 `snap_shares` 도입 후 회귀해 group delete, self-leave, owner removal과 owner/member account deletion 뒤 dangling share나 stale projection이 없고 보존 대상 개인 Snap은 남음을 검증한다.
- [ ] group 상세에 중복된 전체 개별 Snap list, 전체 금액 중심 dashboard, 랭킹을 추가하지 않는다.
- [ ] iOS group list→group Today→member Today와 Home group swipe가 loading·empty·content·retry 및 visible/hidden case를 명시적으로 처리한다.
- [ ] XCUITest는 visible amount/total, hidden raw/UI no-amount, newest-`sharedAt`, no-photo placeholder와 탈퇴 후 접근 거부를 deterministic fixture로 검증한다.
- [ ] 그룹 상세·Home swipe·member Today visible/hidden 중 정확한 Figma frame node·reference·checksum이 canonical manifest에 고정된 상태만 393x852 threshold gate를 적용한다.
- [ ] exact Figma node/reference가 없는 보조 오류 상태는 XCUITest·accessibility 기능 evidence로 판정하되, 핵심 visible/hidden group Today·member Today 화면 자체의 reference가 없으면 기능 green까지만 기록하고 작업은 `design-gated`로 남긴다. 핵심 reference를 확보해 manifest/diff를 통과하기 전에는 `done`으로 전환하지 않는다.
- [ ] VoiceOver는 공개 그룹에서만 금액을 읽고 비공개 그룹에서는 금액을 추론시키는 accessibility value를 만들지 않으며 Dynamic Type·44pt target·reduce motion을 통과한다.

## Test seam

- TDD Red 1: injected `Clock`으로 request tzdb region/UTC의 today를 계산하는 projection domain/application test가 invalid zone·임의 과거 date 거부, latest `sharedAt`, immutable localDay, category placeholder와 membership scope에서 먼저 실패한다.
- TDD Red 2: PostgreSQL 18 HTTP integration test가 visible/hidden separate DTO, lifecycle 반영과 hidden raw JSON negative fields에서 먼저 실패한다.
- TDD Red 3: canonical OpenAPI examples의 visible/hidden schema를 교차 검증해 hidden example에 amount/total/size/order가 섞이면 먼저 실패시킨다.
- TDD Red 4: Swift fixture decode/model test가 hidden type에 금액을 추가하거나 amount-derived layout을 요구할 때 먼저 실패한다.
- TDD Red 5: DEBUG XCUITest가 group Today/member Today visible·hidden·placeholder·accessibility 흐름에서 먼저 실패한다.
- visual seam: exact canonical Figma node/reference가 있는 visible·hidden 상태만 393x852 reference/app/overlay/diff/report를 만들고 각각 독립 scenario로 판정한다. 나머지는 기능 evidence와 디자인 precondition을 남긴다.
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
- 결과: `proposed`; `WORK-029` 완료 뒤 Red부터 기록
- 리뷰: 2026-08-13 사용자가 전체 MVP를 단계별 TDD·통합·visual 검증과 기능별 commit으로 계속 진행하도록 승인함

## Agent rules impact

- 영향 여부: yes
- 근거: amount-hidden privacy가 server JSON·iOS type·layout에서 실제 검증되고 Stage 8 핵심 화면이 완성되면 현재 단계와 검증 근거가 바뀐다.
- 처리 결과: 구현 완료 시 canonical visible/hidden 정책과 `AGENTS.md` privacy invariant를 대조하고 현재 단계·실제 검증 증거를 동기화한다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: stage 시작 SHA를 고정 base로 한 incremental update
- base: `WORK-030` 구현 시작 시 고정
- risk: high (financial privacy, authorization, projection/query drift, visual inference)
- findings와 처리 결과: query/DTO/OpenAPI, iOS typed model과 layout 변경 묶음마다 standard detail로 검사하고 finding은 TDD 수정·전체 회귀·재update한다.

## Decisions and risks

- 2026-08-13 사용자 승인을 기록하되 의존 작업 완료 전까지 상태는 `proposed`로 유지한다.
- `depends_on: [WORK-029]`은 실제 `snap_shares` schema/write contract 의존이면서 사용자의 share command 완전 통과 후 projection 착수 gate다.
- Today query는 client가 날짜를 선택하는 archive API가 아니다. request zone은 today 계산에만 쓰고, 저장된 `localDay`는 immutable owner calendar label로 유지한다.
- hidden projection은 visible DTO의 amount를 `null`로 만드는 방식이 아니라 별도 schema·query mapping으로 구현한다.
- 최신 대표 판단은 `sharedAt`이고 amount나 개인 Snap 생성 시각이 아니다.
- placeholder와 hidden layout은 category·membership/activity 정보만 사용하고 금융 값을 입력으로 받지 않는다.
- visible/hidden Figma reference가 아직 확보되지 않았다면 exact node를 먼저 고정하며 임의 화면으로 pixel parity를 완료 처리하지 않는다.

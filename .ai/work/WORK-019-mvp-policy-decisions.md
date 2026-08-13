---
id: WORK-019
status: done
depends_on: [WORK-012]
owner: codex
---

# 기록·사진·그룹 MVP 세부 정책 확정

## Intent

개인 Snap 저장, private 사진, 그룹 생성·초대와 저장 후 공유를 테스트 가능한 최소 정책으로 고정해 개발 계획 3·6·7·8단계의 차단 사유를 해소한다.

## In scope

- KRW 금액과 owner-local calendar day 경계
- 사진 선택·정규화·quota·private storage guardrail
- 그룹 이름·인원·role·초대·금액 공개 정책
- 사용자 표시명과 기본 avatar 정책
- 개인 저장 후 한 Snap을 한 그룹에 공유하는 진입 방식
- 사진 없는 Snap과 대표 Snap의 fallback 표현
- 후속 기능 작업에 전달할 runtime Acceptance Criteria

## Out of scope

- 코드·schema·Figma·하네스 변경
- 실제 API·DB·R2·iOS runtime 검증
- 알림, OCR, 결제 연동, 공개 피드
- 그룹 role 양도, 복수 관리자, 영구 초대 링크
- 기록별 금액 공개 예외와 복수 그룹 일괄 공유

## Acceptance criteria

- [x] `docs/PRD.md`가 사진 없는 Snap과 photo-optional 제품 경계를 확정하고, `docs/SERVICE_POLICY.md`가 Stage 3의 사진 없는 개인 Snap과 Stage 6의 사진 경로를 구분하며, `docs/SERVICE_POLICY.md`와 `docs/ARCHITECTURE.md`가 금액 `1...999,999,999 KRW`와 immutable `localDay` 실행 경계를 확정한다.
- [x] `docs/SERVICE_POLICY.md`와 `docs/ARCHITECTURE.md`가 Snap당 active image 최대 1개, JPEG 최대 변 `1600px`, `2,097,152 bytes`, EXIF 제거, 최근 24시간 20건 quota와 `7,000,000,000 bytes` storage guardrail을 같은 의미로 정의한다.
- [x] 같은 문서가 upload complete의 server-side bounded verification, invalid object cleanup과 direct PUT 경계를 강제할 수 없을 때의 bounded backend fallback을 확정한다.
- [x] 그룹 owner/member lifecycle, owner 포함 20명, trim 후 1~30 grapheme cluster 이름, 같은 owner의 중복 이름 허용과 생성 시 고정되는 amount visibility가 기준 문서에 확정된다.
- [x] 168시간 단일 active 초대, high-entropy 원문·hash 저장, 재발급 시 revoke, 가입 preview·정원·멱등성 정책이 기준 문서에 확정된다.
- [x] 개인 save 선행, Home의 명시적 share action, 한 command의 한 Snap→한 group, 공유 취소·실패의 개인 save 비rollback 정책이 기준 문서에 확정된다.
- [x] 사진 없는 공유 Snap과 대표 Snap은 고정 category icon/color placeholder와 최신 `sharedAt`을 사용하고 금액 비공개 projection은 amount-derived size/order를 사용하지 않는다고 확정된다.
- [x] Apple 이름이 처음 제공될 때만 유효한 display name으로 저장하고, 없으면 `MoneySnap 사용자`, 기본 avatar는 첫 grapheme 또는 MoneySnap mark를 사용한다고 확정된다.
- [x] `USER_FLOW.md`, `SCREEN_STRUCTURE.md`, `UI_GUIDE.md`가 위 정책을 사용자가 보는 흐름과 표현에 반영하고 해결된 미결정 목록을 제거한다.
- [x] `docs/ADR.md`, `docs/ARCHITECTURE.md`, `docs/DEVELOPMENT_PLAN.md`가 단계 경계와 후속 runtime gate를 동기화한다.
- [x] `CONTEXT.md`의 공용 언어와 `AGENTS.md`의 제품·보안 불변 규칙 요약이 기준 문서와 충돌하지 않는다.

## 후속 기능 작업 항목 인계 메모

WORK-019의 체크는 정책 채택만 증명한다. 다음 runtime 조건은 각 기능 작업이 실패 테스트부터 소유한다.

### Stage 3 — 사진 없는 개인 Snap (`WORK-021`)

- 금액은 KRW 정수 `1...999,999,999`만 허용한다.
- `localDay`는 server `Clock` instant를 제출한 tzdb region `ZoneId` 또는 `UTC`로 변환한 current day·직전 day만 허용한다. numeric offset과 short alias, 미래와 2일 이전은 거부하고 저장 후 바꾸지 않는다.
- 같은 actor·`clientMutationId`·동일 payload replay는 날짜 재검증보다 먼저 최초 결과를 반환하고 payload conflict와 동시 요청은 원자적으로 판정한다.
- record command는 group·visibility·image를 받지 않고 category+amount 개인 Snap을 먼저 durable save한다.

### Stage 6 — private 사진

- 카메라는 1장, 앨범은 최대 3장을 선택하되 각 사진은 category+amount를 가진 별도 Snap으로 순차 저장하며 Snap당 active image는 최대 1개다.
- iOS는 orientation을 보정하고 EXIF를 제거한 JPEG를 최대 변 `1600px` 이하, `2,097,152 bytes` 이하로 만든다.
- grant는 정확한 `image/jpeg`, byte size, SHA-256을 받아 최근 24시간 completed+nonexpired pending 20건과 active+pending+신규 예약 `7,000,000,000 bytes` 경계를 transaction으로 검사한다. 삭제는 24시간 quota를 환급하지 않는다.
- upload intent와 grant는 10분 뒤 만료한다. complete된 unlinked media는 `completedAt`부터 24시간 동안 같은 사용자의 draft 복구 대상으로 보존하고 explicit abort 또는 24시간 경계 이후에만 orphan cleanup job으로 회수한다.
- exact length/type/checksum을 direct PUT에서 실제로 강제하는 held-out contract test를 둔다. 강제할 수 없으면 unrestricted grant를 발급하지 않고 backend가 `2,097,153 bytes`에서 중단하는 bounded stream으로 전달한다.
- complete는 private object를 최대 `2,097,153 bytes` bounded read로 확인해 JPEG signature·dimension·byte size·checksum·EXIF 제거를 재검증한 뒤에만 활성화한다.
- storage guardrail 도달 시 신규 사진 grant만 차단하고 read·delete·사진 없는 Snap은 유지한다.

### Stage 7 — 그룹·초대

- owner 1명과 member, owner 포함 최대 20명을 DB transaction과 권한 테스트로 강제한다.
- group name은 trim 후 1~30 grapheme cluster이고 같은 owner가 같은 이름의 다른 그룹을 만들 수 있다.
- amount visibility는 생성 시 고정하고 변경 endpoint를 만들지 않는다.
- member self-leave, owner member removal, owner non-leave/group delete와 group delete가 개인 Snap을 지우지 않는 경계를 검증한다.
- owner account deletion은 owned group과 해당 share를 삭제한 뒤 account cascade가 owner 개인 Snap을 삭제한다. 다른 member의 개인 Snap은 보존한다.
- 초대 원문은 server CSPRNG 최소 128-bit entropy, hash-only storage, no logging, 168시간 만료, 그룹당 single active/reissue revoke를 강제한다.
- join은 인증된 POST body만 원문을 받고 확정 전에 name·visibility preview를 제공하며 expired·revoked·full 거부, 기존 member 멱등 성공, capacity+join 원자성을 검증한다.

### Stage 8 — 명시적 그룹 공유

- Home의 share action은 durable personal Snap 한 건에서만 열리고 한 command는 한 group만 대상으로 별도 `clientMutationId`를 사용한다.
- share skip·취소·실패는 개인 save를 rollback하지 않으며 Home에서 같은 의미 command로 재시도할 수 있다.
- multi-Snap·multi-group batch UI는 만들지 않는다.
- 사진 없는 공유 Snap은 category별 고정 icon/color placeholder를 사용하고 member 대표 Snap은 해당 날짜의 최신 `sharedAt`을 사용한다.
- amount-hidden response에는 amount·total·amount-derived size/order field가 존재하지 않는 JSON 부정 계약 테스트를 둔다.

## Test seam

- 이 작업은 문서 전용이다. 실행 경계 검증은 위 인계 메모를 각 Stage 작업의 domain·HTTP·PostgreSQL·iOS 테스트로 옮겨 Red부터 시작한다.
- 기준 문서끼리 같은 용어와 숫자를 사용하고 해결된 미결정 항목을 남기지 않는지 diff로 검토한다.

## Verification

```text
git diff --check
$required = @('AGENTS.md','CONTEXT.md','.ai/README.md','.ai/harness.yaml','.ai/GRAPHS.md','.ai/LOOPS.md','.ai/templates/work-item.md','docs/AI_ENVIRONMENT.md'); $missing = $required | Where-Object { -not (Test-Path -LiteralPath $_) }; if ($missing) { $missing; exit 1 }
```

## Evidence

- 실행 명령:
  - 2026-08-13 사용자: WORK-019~022와 고정 하네스·AGENTS 변경 모두 승인
  - `git diff --check`
  - 필수 AI 환경 경로 존재 검증 PowerShell command
- 결과:
  - `git diff --check` exit 0
  - `Required AI environment paths: OK`
  - 승인된 기록·사진·그룹 기본값을 canonical 문서와 `AGENTS.md`에 동기화함
  - 인증 단계의 실제 완료 상태도 `docs/ARCHITECTURE.md`, `docs/DEVELOPMENT_PLAN.md`, `AGENTS.md`에 함께 최신화함
- 리뷰: runtime 완료를 주장하던 기존 AC를 문서 채택 AC와 Stage별 인계 메모로 분리함. 독립 consistency review와 2회 re-review의 문서 소유권 과장·사진 수 모호성·PUT fallback 요약 finding을 모두 반영했고 최종 finding 0건; 코드·schema·Figma·인프라는 변경하지 않음

## Agent rules impact

- 영향 여부: yes
- 근거: 사진 quota, 시간대, 그룹 생성·초대·공개와 공유 불변 규칙이 제품·보안 gate와 다음 구현 순서를 바꾼다.
- 처리 결과: 기준 문서를 먼저 갱신하고 `AGENTS.md`에는 장기 실행 계약에 필요한 요약만 동기화한다.

## Code Review Graph

- 코드 변경 여부: no
- graph action: skipped
- base: `593e527`
- risk: high (privacy, authorization, quota, date ownership)
- findings와 처리 결과: 문서 전용 작업이므로 graph update를 생략하고 각 구현 작업에서 고정 base 증분 update를 수행한다.

## Decisions and risks

- 2026-08-13 사용자가 본 정책 기본값과 후속 하네스 작업을 명시적으로 승인했다.
- Stage 3은 사진 없는 개인 record를 먼저 닫고 Stage 6에서 camera·PhotosUI·normalization·R2를 함께 완성해 버려지는 production preview와 순환 의존을 피한다.
- direct object-store grant가 exact byte boundary를 실제로 강제하는지는 문서만으로 완료하지 않고 Stage 6 held-out contract test로 판정한다.
- no-photo category·amount sheet의 정확한 Figma reference가 없는 경우 기능 검증과 승인된 component evidence만 기록하고 임의 pixel parity를 주장하지 않는다.

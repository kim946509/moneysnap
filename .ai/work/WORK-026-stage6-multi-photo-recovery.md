---
id: WORK-026
status: proposed
depends_on: [WORK-025]
owner: codex
---

# Stage 6 앨범 최대 3장 순차 저장·quota·복구

## Intent

앨범에서 최대 세 장을 고른 사용자가 사진마다 별도 개인 Snap을 순서대로 확실히 저장하고, 중간 실패·취소·만료와 object 삭제 실패가 앞서 저장한 기록이나 private storage 회계를 깨뜨리지 않게 한다.

## In scope

- PhotosUI 선택 상한 3장과 current-photo queue/progress state
- 각 사진의 독립 normalize → intent/upload/complete → category+amount Snap record 순차 처리
- 현재 사진만 같은 command로 retry하고 이전 durable Snap을 rollback하지 않는 recovery
- 사용자별 rolling 24시간 completed+nonexpired pending 20건 admission
- 전역 active+nonexpired pending+신규 reservation `7,000,000,000 bytes` admission
- 10분 intent expiry, 별도 승인된 canonical orphan TTL, failed pending, eligible orphan와 Snap delete object의 결정론적 cleanup·bounded retry
- quota·reservation·cleanup 동시성과 replay를 검증하는 PostgreSQL/Fake ObjectStore 통합 테스트
- multi-photo Swift model/API·XCUITest·393x852 progress/error visual evidence
- 별도 승인된 held-out real R2 exact PUT·cleanup contract lane과 최종 실제 iPhone 경계

## Out of scope

- 한 Snap에 여러 사진 연결, batch Snap API, 여러 사진의 category·amount를 한 화면에서 편집하는 표
- 이전에 성공한 Snap의 일괄 rollback 또는 all-or-nothing DB/R2 transaction
- 사진 교체, 사진 순서 편집, background upload, offline sync
- group 공유·복수 group batch, public URL과 profile 사진
- R2 lifecycle rule을 application cleanup의 대체 증거로 사용하는 일
- default CI의 live Neon/R2 call, 서버 배포와 production data cleanup

## Acceptance criteria

- [ ] PhotosUI는 한 기록 session에서 1...3장만 선택할 수 있고 selection order를 보존한다. 카메라 경로는 계속 한 장이며 사진 없음 경로도 계속 사용할 수 있다.
- [ ] 여러 장을 선택하면 current photo 한 장과 `1/3` 형태의 진행 상태를 category·amount 단계에서 유지하고, 대량 입력표나 한 Snap의 복수 image 배열을 만들지 않는다.
- [ ] 각 사진은 별도 media mutation ID, record `clientMutationId`, category와 amount를 가진 개인 Snap 한 건으로 순차 저장되며 다음 사진은 현재 Snap의 durable success receipt 뒤에만 시작한다.
- [ ] 성공한 이전 사진은 Home에 정확히 한 번 반영되고, 두 번째·세 번째 사진의 upload·complete·record 실패·취소가 이를 rollback하거나 공유 상태로 바꾸지 않는다.
- [ ] commit-unknown retry는 현재 사진의 immutable normalized bytes/checksum, media operation와 record command·mutation ID만 재사용하고 새 ID를 자동 생성해 중복 object·Snap을 만들지 않는다.
- [ ] 현재 intent가 만료됐거나 서버가 명시적으로 terminal invalid로 판정한 경우에만 동일 draft에서 새 intent를 만들 수 있고, 이전 reservation/object 상태 확인 없이 새 grant를 연쇄 발급하지 않는다.
- [ ] 취소는 현재 처리 중 intent/command만 명시적 abort 대상으로 표시한다. abort도 unlinked media에 대한 조건부 cleanup claim으로 처리해 이미 record transaction이 claim·연결한 media를 삭제하지 않는다. 아직 시작하지 않은 local queue에는 server side effect가 없고, 앞서 저장된 Snap은 유지되며 사용자가 이를 알 수 있다.
- [ ] actor별 신규 reservation transaction은 server `Clock`의 rolling 24시간 안에 completed upload와 아직 만료되지 않은 pending upload를 함께 세어 신규 건을 포함해 최대 20건만 허용한다.
- [ ] 같은 actor의 20번째·21번째 동시 요청, 여러 pending replay와 시간 경계 테스트에서 최대 20건만 admission되고 duplicate replay는 count나 reservation bytes를 다시 늘리지 않는다.
- [ ] 사진이나 Snap 삭제는 completed upload의 24시간 count를 환급하지 않고 정확히 24시간 window를 벗어난 뒤에만 새 admission 여지를 만든다.
- [ ] 모든 actor의 active media bytes와 nonexpired pending reserved bytes에 신규 declared bytes를 더한 값이 `7,000,000,000` 이하여야 하며, 동시 요청에서도 하나의 transaction 경계로 초과하지 않는다.
- [ ] storage guardrail 도달·초과 상태에서는 신규 사진 intent만 안정된 quota error와 correlation ID로 거부하고 기존 사진 read·delete, 사진 없는 Snap 저장과 인증 흐름은 유지한다.
- [ ] pending reservation은 server `Clock`이 10분 expiry를 지나면 nonexpired pending 계산에서 정확히 한 번 제외되고, cleanup은 상태 전이와 object 존재 여부를 확인해 expired/orphan object를 replay-safe하게 정리한다.
- [ ] `ACTIVE_UNLINKED`의 canonical orphan expiry는 server `Clock`의 `completedAt + 24시간`이다. 그 전에는 같은 owner의 relaunch recovery가 동일 `ImageRef`로 이어지고, 경계 이후에는 복구 불가 안내 후 새 upload만 허용한다.
- [ ] complete 성공은 server `Clock`의 `completedAt`을 가진 `ACTIVE_UNLINKED` row를 만들며, 단순히 Snap에 아직 연결되지 않았거나 app process가 종료됐다는 이유로 canonical orphan TTL 전에 cleanup target이 되지 않는다.
- [ ] unlinked active object는 명시적 abort가 조건부 claim에 성공했거나 승인된 canonical orphan TTL이 지났고 여전히 unlinked·unclaimed일 때만 orphan cleanup eligible이다. complete 실패 object, expired·failed pending, Snap 삭제로 분리된 object와 partial fallback object는 각각 상태에 맞는 unique cleanup target을 만든다.
- [ ] Snap record/link transaction은 canonical orphan expiry 전의 `ACTIVE_UNLINKED` row를 조건부 claim해 Snap insert와 함께 `LINKED`로 commit하고, cleanup worker는 eligible row를 `CLEANUP_CLAIMED`로 조건부 claim한다. 두 claim은 동시에 성공할 수 없으며 cleanup은 `LINKED` 또는 record-claimed ref의 object를 삭제하지 않는다.
- [ ] recovery window 안의 link와 explicit abort/expiry 경계 cleanup 경합에서 link가 먼저 claim하면 Snap과 image가 유지되고 cleanup은 no-op이다. abort 또는 canonical expiry eligibility를 cleanup이 먼저 claim하거나 record command가 expiry 후 시작되면 record는 안정된 `NOT_ACCESSIBLE`로 실패하고 삭제 중 object를 연결하지 않는다. 성공 record mutation replay는 cleanup·expiry 판정보다 먼저 최초 receipt를 반환한다.
- [ ] cleanup worker는 injected `Clock`, deterministic retry policy, attempt와 `nextAttemptAt`을 사용하고 같은 target의 중복 job·동시 worker 실행에서도 object 삭제와 byte decrement를 최대 한 번만 반영한다.
- [ ] transient fake `ObjectStore` 실패는 예정된 다음 attempt에서 성공하고, 설정된 bounded max attempt를 넘은 permanent 실패는 관찰 가능한 terminal/manual-recovery 상태가 되어 무한 loop하지 않는다.
- [ ] 실제 object 삭제가 확인되기 전에는 active storage bytes를 줄이지 않는다. delete-not-found는 소유 key가 맞는 경우 멱등 성공으로 정산하고, cross-owner key나 상태가 다시 active/linked된 target은 삭제하지 않는다.
- [ ] Snap 삭제 직후 개인 Home·상세에서는 image/Snap이 보이지 않고, 연관된 group projection 삭제 계약은 Stage 8의 share lifecycle을 유지하며 object cleanup 실패가 사용자 데이터 resurrection을 만들지 않는다.
- [ ] 재인증 계정 탈퇴 transaction은 해당 actor의 pending·`ACTIVE_UNLINKED`·linked media object key와 byte 회계 정보를 user FK와 독립된 cleanup tombstone/job으로 먼저 복사·전환한 뒤 account rows를 삭제한다. R2 삭제 실패는 bounded retry하고 다른 actor의 row/object는 보존한다.
- [ ] fake `ObjectStore` regression은 계정 탈퇴 후 DB user/media 접근이 즉시 사라지고 linked/pending/unlinked object가 모두 cleanup되며, transient failure 뒤 재시도 성공 시 byte 회계가 정확히 한 번 줄고 다른 owner object는 남는지 검증한다.
- [ ] server schema와 cleanup query는 expand-first이고 이전 JAR이 새 table/column을 무시할 수 있으며 DB down migration을 자동화하지 않는다.
- [ ] local full suite는 fake `ObjectStore`와 PostgreSQL 18 Testcontainers만 사용해 20/24h, 7GB, expiry, orphan, delete, bounded retry와 concurrency를 재현하고 Neon·R2 secret을 요구하지 않는다.
- [ ] XCUITest DEBUG fixture는 3장 선택, 첫 장 성공 후 두 번째 transient 실패·retry, current cancel과 마지막 완료를 검증하고 실제 system photo library의 데이터에 의존하지 않는다.
- [ ] 각 current photo가 complete된 뒤 app을 종료·재실행하는 DEBUG fixture에서 같은 actor는 queue index·preview·category/amount draft를 복원해 이어서 저장하거나 현재 사진만 명시적으로 버릴 수 있고, 이전 durable Snap과 아직 시작하지 않은 사진은 바뀌지 않는다.
- [ ] 393x852 evidence는 승인된 Figma node/reference가 있는 `1/3` progress, current error/retry와 Home 누적 상태만 비교하며 PhotosPicker system UI 자체를 snapshot baseline으로 삼지 않는다.
- [ ] WORK-025 단일-photo safety와 본 작업의 quota·cleanup·multi-photo recovery가 함께 전체 회귀를 통과해야 Stage 6 완료와 production media entry point 활성화를 검토한다.

## Test seam

- queue seam: injected ordered media fixtures와 recording single-photo pipeline으로 현재 index, immutable retry, cancel과 durable receipt 누적을 Swift test에서 먼저 실패시킨다.
- admission seam: fixed `Clock`과 PostgreSQL 18 Testcontainers로 19/20/21 count, exact 24시간 경계, exact 7GB와 multi-actor concurrency를 검증한다.
- reservation seam: 동일 media mutation replay, payload conflict, intent expiry와 승인된 canonical orphan expiry 직전·정확한 경계·직후를 HTTP 결과와 reservation state로 검증한다.
- cleanup seam: fixed `Clock`과 fake `ObjectStore`가 exists/delete 성공, not-found, N회 transient failure와 permanent failure를 제공한다. scheduler를 직접 한 tick씩 실행해 recovery window 전 no-op, explicit abort, canonical expiry 후 claim과 duplicate worker를 검증한다.
- link-race seam: PostgreSQL barrier로 record/link transaction과 cleanup conditional claim을 양쪽 순서로 경합시켜 linked object는 보존되고 cleanup-claimed object는 연결되지 않으며 양쪽 성공 상태가 존재하지 않음을 검증한다.
- delete seam: image-linked Snap deletion, invalid complete, canonical 24시간 orphan expiry가 지난 unlinked active와 partial upload를 각각 만들고 object 확인 전후의 byte accounting을 검증한다.
- iOS UI seam: DEBUG fixture source가 system PhotosPicker를 대체하고 3개 image의 선택 순서, `1/3...3/3`, retry/cancel과 Home receipt를 XCUITest에 노출한다.

## Verification

```text
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.media.*Admission*" --no-daemon --console=plain
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.media.*Cleanup*" --no-daemon --console=plain
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.media.*" --no-daemon --console=plain
cd server; .\gradlew.bat test --no-daemon --console=plain
cd server; .\gradlew.bat bootJar --no-daemon --console=plain
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
bash ios/scripts/test.sh
bash ios/scripts/capture-visual-baseline.sh
git diff --check
```

- 빠른 queue/rules/fake ObjectStore test는 각 Red/Green loop마다 실행한다.
- concurrency·cleanup fault matrix, 서버 전체 회귀, macOS native/XCUITest와 full visual suite는 quota·recovery 기능 묶음이 끝난 시점에 한 번 실행하고 Evidence에 실제 시간과 결과를 남긴다.
- real R2 held-out suite는 별도 승인 후 dev private bucket의 unique test prefix에서 exact PUT 변경·누락·overflow, complete read와 cleanup을 검증하고 생성 object 목록과 정리 결과를 남긴다. 이 lane은 default CI나 production bucket을 사용하지 않는다.

## Evidence

- 실행 명령:
- 결과:
- 리뷰: 2026-08-13 사용자 "모두 승인 계속해주ㅜ"로 전체 MVP 후속 기능 진행과 단계별 작업 준비를 승인함. 장시간·외부 R2·실제 device 증거는 local deterministic suite와 분리해 기록한다.

## Agent rules impact

- 영향 여부: yes
- 근거: 24시간/20건·7GB admission, object lifecycle 회계와 Stage 6 완료 gate가 실제 runtime·운영·검증 계약이 된다.
- 처리 결과: 구현 전 canonical policy 수치를 바꾸지 않고 OpenAPI·architecture·operations 문서를 먼저 동기화하며, 완료 후 `AGENTS.md`의 현재 단계와 실제 검증 명령·device/R2 미검증 경계를 갱신한다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: WORK-025 완료 SHA를 고정 base로 incremental update
- base: WORK-026 시작 시 WORK-025 완료 SHA로 고정
- risk: high (quota race, byte accounting, cleanup/data loss, idempotency, multi-step client recovery)
- findings와 처리 결과: admission, cleanup, Swift queue의 의미 있는 묶음마다 standard detail로 영향·테스트 공백을 확인하고 TDD로 수정한 뒤 다시 incremental update한다. graph가 비었거나 손상된 경우에만 full rebuild한다.

## Decisions and risks

- 앨범 세 장은 batch가 아니라 WORK-025의 단일-photo pipeline을 최대 세 번 순차 호출한다. 이전 성공을 보상 transaction으로 지우지 않는다.
- `depends_on: [WORK-025]`는 실제 single-photo pipeline·media state schema와 link claim을 재사용하는 blocking edge다. WORK-025의 WORK-024 edge가 사용자의 strict 단계 진행 결정을 보존하므로 WORK-026에 WORK-021·024를 중복 나열하지 않는다.
- upload/record의 현재 작업만 retry 또는 abort하고 아직 시작하지 않은 사진에는 intent를 미리 만들지 않아 quota reservation·메모리 사용을 제한한다.
- cleanup job은 R2 lifecycle rule이나 best-effort fire-and-forget으로 대체하지 않는다. DB state와 object 확인 결과가 회계의 source of truth다.
- complete 직후와 relaunch 후의 정상 draft recovery window를 orphan과 동일시하지 않는다. explicit abort 또는 별도 승인된 canonical orphan TTL만 cleanup eligibility를 열고, DB conditional claim이 record/link와 cleanup의 승자를 정한다.
- 승인된 upload intent 10분을 active-unlinked 보존 시간으로 복제하지 않는다. `completedAt + 24시간` 전에는 자동 cleanup하지 않고, 경계 시각부터 조건부 cleanup claim과 복구 불가 UX를 적용한다.
- fake `ObjectStore` local suite가 기능 완료의 결정론적 gate다. real R2는 provider contract를 판정하는 held-out evidence이며 실패하면 direct PUT을 끄고 WORK-025의 bounded backend fallback을 유지한다.
- default PR CI에는 external credential을 주입하지 않는다. real R2 lane의 object 삭제도 파괴 범위를 unique test prefix로 먼저 확인한 뒤 수행한다.
- Simulator/XCUITest는 app queue와 recovery만 증명한다. 실제 PhotosUI 다중 선택, limited-library 권한, 큰 HEIC 3장 메모리·방향·background 전환은 최종 단계에서 사용자 iPhone으로 확인하고 그전에는 device evidence를 완료로 표시하지 않는다.

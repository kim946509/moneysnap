---
id: WORK-025
status: proposed
depends_on: [WORK-024]
owner: codex
---

# Stage 6 단일 private 사진 저장·표시

## Intent

로그인한 사용자가 카메라로 한 장을 촬영하거나 앨범에서 한 장을 골라 안전하게 정규화·업로드하고, 자신이 소유한 개인 Snap 한 건에만 연결해 Home과 상세에서 본다.

## In scope

- 카메라 1장과 PhotosUI 단일 선택을 같은 단일-photo `CaptureFlow`로 연결
- iOS orientation 보정, EXIF 제거, JPEG 변환, 최대 변 `1600px`, 최대 `2,097,152 bytes`, SHA-256 계산
- server-generated object key, 10분 upload intent와 owner-scoped opaque `ImageRef`
- exact length·`image/jpeg`·checksum을 강제하는 direct R2 PUT 또는 이를 증명하지 못할 때의 Spring Boot bounded stream fallback
- upload complete의 `2,097,153 bytes` bounded read, 실제 JPEG 내용 재검증과 복구 가능한 `ACTIVE_UNLINKED` 상태
- active·unlinked·동일 owner `ImageRef` 하나를 cleanup과 경합하지 않는 claim으로 개인 Snap record에 원자적으로 연결
- owner authorization 뒤에만 발급하는 short-lived GET grant와 Home·Snap 상세 사진 표시
- OpenAPI·Flyway·Spring HTTP/PostgreSQL·Swift model/API·XCUITest·393x852 visual 검증
- local test의 fake `ObjectStore`와 별도 승인된 held-out real R2 contract lane

## Out of scope

- 앨범 최대 3장 queue, 사진별 순차 durable save와 중간 복구; `WORK-026`이 소유한다.
- 최근 24시간 20건·전역 `7,000,000,000 bytes` admission, expiry/orphan/delete cleanup의 완결; `WORK-026`이 Stage 6 완료 gate로 소유한다.
- 사진 교체·편집·배경 제거·OCR·원본 보관·multipart upload
- 그룹 member의 사진 읽기 권한; Stage 8 공유 조회가 현재 membership을 확인한 뒤 같은 media read boundary를 확장한다.
- public bucket, permanent object URL, iOS의 R2 credential, 원본 파일명 저장
- live R2 호출을 default CI나 pull request에 넣는 일
- 서버 배포, Apple activation과 실제 iPhone 촬영 완료 판정

## Acceptance criteria

- [ ] 카메라는 한 장만 반환하고 PhotosUI 단일-photo 경로도 한 장만 현재 draft로 가져오며, 권한 거부·지원하지 않는 기기는 앨범 또는 사진 없음 선택으로 복귀한다.
- [ ] PhotosUI system picker는 broad photo-library 권한을 선요청하지 않고, 카메라 권한은 촬영 선택 시점에만 요청한다. 로그인·Home 진입에서는 어떤 사진·카메라 권한도 요청하지 않는다.
- [ ] iOS 정규화 결과는 픽셀 방향이 바로 선 `image/jpeg`, 최대 변 `1600px` 이하, `2,097,152 bytes` 이하이고 EXIF/GPS block을 포함하지 않으며 업로드 전에 실제 bytes의 SHA-256을 계산한다.
- [ ] 회전·mirror·wide-gamut·최대 경계·압축해도 제한을 만족하지 못하는 fixture가 결정론적 Swift test를 통과하고, 정규화 실패 시 intent를 만들거나 저장 성공처럼 표시하지 않는다.
- [ ] 인증된 intent request는 byte size, exact `image/jpeg`, SHA-256만 받고 object key는 서버가 생성하며 client path·원본 파일명·URL을 신뢰하거나 저장하지 않는다.
- [ ] upload intent와 upload instruction은 server `Clock` 기준 정확히 10분 뒤 만료하고 다른 actor, 만료 intent와 replay-conflict payload를 사용할 수 없다.
- [ ] `ACTIVE_UNLINKED`는 server `Clock`의 `completedAt`부터 24시간 동안 같은 사용자의 draft 복구 대상으로 보존하고, explicit abort 또는 `completedAt + 24시간` 경계 이후에만 orphan cleanup 대상이 된다. 승인된 10분 upload intent 만료를 이 보존 시간으로 재사용하지 않는다.
- [ ] direct PUT mode는 exact `Content-Length`, `Content-Type`, checksum의 누락·변경·초과가 object 저장으로 이어지지 않는 held-out contract를 통과할 때만 활성화된다.
- [ ] 위 exact 경계를 real R2에서 증명하지 못하면 서버는 unrestricted presigned PUT을 반환하지 않고 `2,097,153`번째 byte에서 중단하는 authenticated bounded stream instruction만 반환한다.
- [ ] bounded fallback은 declared length·type·checksum 불일치와 overflow를 거부하고 partial object를 active로 만들지 않으며, body 전체를 heap에 적재하지 않는다.
- [ ] complete는 object metadata만 신뢰하지 않고 private object를 최대 `2,097,153 bytes`로 읽어 JPEG signature, 실제 byte size, checksum, 최대 dimension과 EXIF 제거를 다시 검증한다.
- [ ] complete 검증에 성공한 동일 owner media만 `completedAt`과 `orphanExpiresAt = completedAt + 24시간`을 가진 `ACTIVE_UNLINKED`가 되고 opaque `ImageRef`를 발급한다. pending·expired·invalid media에는 이를 발급하지 않는다.
- [ ] Snap record는 optional `imageRef` 하나만 받도록 canonical contract를 확장하고 raw object key·upload URL·복수 image ID·정의되지 않은 media property를 `400 INVALID_REQUEST`로 거부한다.
- [ ] record idempotency fingerprint는 `imageRef`를 포함하며 동일 owner의 복구 가능한 `ACTIVE_UNLINKED` ref를 Snap insert와 같은 DB transaction에서 조건부 claim해 연결한다. 이 claim은 cleanup claim과 동시에 성공할 수 없고, 연결된 media를 cleanup이 다시 가져갈 수 없다.
- [ ] cross-owner, 이미 다른 Snap에 연결된 ref, canonical orphan TTL이 지난 ref와 cleanup이 먼저 claim한 ref의 재사용은 자원 존재·내부 상태를 누설하지 않는 `NOT_ACCESSIBLE`로 실패한다. 이미 성공한 record mutation replay는 media 상태와 orphan expiry를 다시 판정하기 전에 최초 receipt를 반환한다.
- [ ] record 실패나 결과 불명 retry는 같은 record command·mutation ID를 사용하고, 같은 성공 receipt와 Snap 하나만 만든다.
- [ ] app이 complete 뒤 record 전에 종료되면 같은 로그인 사용자의 다음 실행에서 보호된 로컬 current-draft 상태를 발견해 사진 preview·진행 상태와 같은 `ImageRef`로 `이어서 기록` 또는 `현재 사진 버리기`를 제공한다. 새 intent를 자동 발급하거나 이미 완료된 upload를 반복하지 않는다.
- [ ] relaunch에서 이어가기는 같은 category·amount draft와 record mutation ID가 이미 고정됐다면 이를 재사용한다. 버리기는 명시적 abort를 보내고, logout·계정 변경·탈퇴에서는 다른 사용자에게 draft를 노출하지 않도록 로컬 preview와 참조를 제거한다.
- [ ] Home·상세 API는 opaque image presence/reference만 제공하고 permanent R2 URL·object key·credential을 response나 log에 포함하지 않는다.
- [ ] media read 요청은 owner scope를 먼저 확인한 뒤 server-controlled short-lived GET grant와 `expiresAt`을 발급한다. 다른 actor와 없는 ref는 같은 `NOT_ACCESSIBLE` 계약으로 거부한다.
- [ ] iOS는 expired GET grant를 영구 cache하지 않고 재발급할 수 있으며 loading·실패·재시도 상태가 금액·category와 Snap 소유권 표현을 가리지 않는다.
- [ ] Snap 삭제 요청은 연결된 image를 더 이상 Home·상세에 노출하지 않고 cleanup 대상으로 표시하되, 실제 object 삭제·byte 회계·bounded retry의 완료는 `WORK-026`이 검증한다.
- [ ] local server test는 fake `ObjectStore`로 overflow, checksum/type/signature/dimension/EXIF, owner attach/read와 partial failure를 재현하며 Neon·R2 secret과 network를 사용하지 않는다.
- [ ] Swift unit/API test와 DEBUG media-source XCUITest가 camera/PhotosUI adapter 바깥의 단일-photo 흐름, permission denial, normalize failure, upload·complete·record retry와 Home/detail 표시를 검증한다.
- [ ] 승인된 Figma node/reference가 있는 capture preview·Home·상세 상태만 393x852 visual threshold로 완료하고, reference가 없는 system picker/camera UI의 pixel parity를 주장하지 않는다.
- [ ] WORK-026의 quota·cleanup gate가 끝나기 전에는 production media entry point를 활성화하거나 Stage 6 완료로 표시하지 않는다.

## Test seam

- server domain seam: fixed `Clock`, owner IDs와 in-memory bytes를 사용하는 media intent·complete·attach rules test를 먼저 실패시킨다.
- persistence seam: PostgreSQL 18 Testcontainers와 Flyway로 intent expiry, canonical orphan expiry, owner attach, one-active-image constraint, 동시 attach와 attach/cleanup conditional-claim 경합을 HTTP 결과에서 검증한다.
- object seam: 최소 `ObjectStore` interface의 fake가 exact upload, truncated/overflow read, corrupt JPEG, transient read/delete와 stored bytes를 통제한다.
- fallback seam: chunked request fixture가 `2,097,153`번째 byte에서 종료되고 active ref가 생기지 않는지 검증한다.
- iOS normalization seam: orientation·mirror·metadata·large image fixture를 순수 byte transform에 넣고 output dimension, metadata와 checksum을 검사한다.
- iOS flow seam: camera/PhotosUI 자체는 얇은 adapter로 두고 DEBUG fixture source와 recording HTTP client로 permission, preview, immutable retry command와 receipt를 검증한다.
- relaunch seam: protected draft store fake로 complete 직후 process 종료를 재현하고 같은 actor의 resume/discard, 다른 actor·logout의 local isolation과 no-reupload를 검증한다.
- UI/visual seam: XCUITest는 system picker/camera를 자동화하지 않고 app-owned source chooser 이후의 결정론적 fixture 흐름만 실행한다.

## Verification

```text
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.media.*" --no-daemon --console=plain
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.snap.*" --no-daemon --console=plain
cd server; .\gradlew.bat test --no-daemon --console=plain
cd server; .\gradlew.bat bootJar --no-daemon --console=plain
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
bash ios/scripts/test.sh
bash ios/scripts/capture-visual-baseline.sh
git diff --check
```

- focused server·Swift test는 각 Red/Green loop에서 실행한다.
- Testcontainers 전체 회귀, macOS native/XCUITest와 393x852 visual suite 같은 오래 걸리는 검증은 단일-photo 기능 묶음이 완료됐을 때 실행한다.
- real R2 contract test는 dev private bucket의 격리 prefix와 최소 권한 credential을 쓰는 별도 승인 lane에서만 실행하고, default CI·PR·production bucket에는 넣지 않는다.

## Evidence

- 실행 명령:
- 결과:
- 리뷰: 2026-08-13 사용자 "모두 승인 계속해주ㅜ"로 전체 MVP 후속 기능 진행과 단계별 작업 준비를 승인함. 실제 실행 결과는 Red/Green과 held-out lane을 구분해 기록한다.

## Agent rules impact

- 영향 여부: yes
- 근거: 첫 private media runtime, 실제 upload/read authorization, object-store fallback과 iOS 사진 검증 경계가 현재 단계와 검증 설명을 바꾼다.
- 처리 결과: 구현 시 canonical OpenAPI·architecture·운영 문서를 먼저 갱신하고, 완료 상태와 실제 검증 명령만 `AGENTS.md`에 동기화한다. 기존 quota·privacy 불변 규칙은 완화하지 않는다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: 시작 시 graph 유효성을 확인하고 Stage 6 고정 start SHA 기준 incremental update
- base: WORK-025 시작 시 고정
- risk: high (owner authorization, untrusted image parsing, SSRF/object key, bounded I/O, idempotency)
- findings와 처리 결과: media schema/server와 Swift capture의 의미 있는 변경 묶음마다 standard detail로 검사하고 actionable finding은 TDD 수정·재update한다. graph가 없거나 손상된 경우에만 full rebuild한다.

## Decisions and risks

- WORK-025는 한 사진의 end-to-end 안전 경계를 먼저 만들고, WORK-026이 quota·cleanup·multi-photo recovery를 닫을 때까지 Stage 6을 완료 또는 production-ready로 주장하지 않는다.
- 독립 리뷰에서 compile/schema의 최소 선행 조건은 WORK-019 정책과 WORK-021 개인 record임을 확인했다. 그러나 사용자가 각 기능 단계를 완전히 닫은 뒤 다음 단계로 진행하라고 정했고, 이 작업이 WORK-024의 Snap 상세 표시와 media-aware 삭제 handoff를 직접 확장하므로 `depends_on: [WORK-024]`를 의도적인 blocking edge로 유지한다. WORK-024는 WORK-021·019를 transitive하게 포함하며 문서의 Stage 6 최소 기술 의존성을 부정하지 않는다.
- camera와 PhotosUI는 source adapter만 다르고 정규화 이후에는 하나의 single-photo pipeline을 사용한다. WORK-026은 PhotosUI selection limit만 최대 3장으로 확장한다.
- direct PUT은 추정으로 활성화하지 않는다. local 완료 경로는 bounded backend fallback을 항상 검증하고, held-out real R2 결과가 exact contract를 입증할 때만 direct mode를 선택한다.
- `ObjectStore`는 fake와 R2라는 실제 두 구현을 격리하기 위한 feature-local port 하나만 둔다. 범용 upload framework, event bus 또는 media microservice를 만들지 않는다.
- complete와 record 사이에는 DB/R2 분산 transaction을 가장하지 않는다. `ACTIVE_UNLINKED`는 explicit abort 또는 별도 승인된 canonical orphan TTL 이후에만 cleanup 대상이며, record transaction의 조건부 media claim과 WORK-026 cleanup claim이 승자를 하나로 정해 정상 draft 작성 중 object 삭제를 막는다.
- upload intent의 승인된 10분은 upload 시작 경계일 뿐 complete된 draft의 보존 시간이 아니다. 24시간 복구 창 안에는 같은 owner가 동일 `ImageRef`로 재개하고, 만료 후에는 복구 불가 안내 뒤 새 upload가 필요하다.
- real R2 lane은 외부 상태·비용·secret을 사용하므로 실행 직전 승인 경계를 다시 확인하고, 생성한 test object를 같은 격리 prefix 안에서만 정리한다.
- Simulator evidence는 app-owned flow와 rendering을 증명한다. 실제 카메라 권한, HEIC/회전 입력, 메모리와 촬영 복귀는 Apple activation 후 최종 실제 iPhone 검증에 남기고 그전에는 device 완료로 표시하지 않는다.

---
id: WORK-033
status: proposed
depends_on: [WORK-032]
owner: codex
---

# Stage 10 MVP release candidate 통합 안정화

## Intent

외부 배포 없이 Stage 1~9의 전체 MVP를 하나의 고정 release candidate로 묶어 기능·계약·시각·접근성·성능·보안과 rollback 호환성을 반복 검증 가능하게 만든다.

## In scope

- Stage 1~9 전체 사용자 journey와 실패·복구 흐름의 deterministic server/iOS integration suite
- Stage 10 시작 시 고정한 OpenAPI v1 baseline과 current contract의 backward compatibility gate
- clean install, Stage 9 schema upgrade와 이전 server artifact rollback을 위한 expand-first migration compatibility drill
- 서버 전체 unit·PostgreSQL integration·OpenAPI·Docker packaging·fake deployment rollback suite
- iOS 전체 Swift native·XCUITest·393x852 visual manifest와 release-build DEBUG fixture 격리
- VoiceOver·44pt target·Dynamic Type·Reduce Motion 전체 화면 matrix
- 고정 fixture의 server p95/API query bound와 iOS launch·navigation·canvas interaction performance evidence
- owner/nonmember/left-member/hidden-amount/media/session/account-delete security regression
- repository·history·artifact secret scan, GitHub Secret Scanning/Push Protection 상태와 unresolved alert 확인
- release candidate SHA·artifact checksum·known limitations·rollback compatibility를 담은 readiness report

## Out of scope

- Ubuntu, Neon dev/prod, R2 dev/prod, Cloudflare, Nginx Proxy Manager 또는 monitoring에 대한 실제 변경
- Apple App ID·certificate/key, Xcode Cloud workflow, archive upload와 TestFlight 배포
- MVP 밖 알림, 공개 feed, 통계·예산, Android/web 또는 release 중 발견한 새 제품 기능
- AC나 visual threshold를 맞추기 위한 완화, flaky test 무시와 baseline 자동 갱신
- DB down migration 또는 production data restore

## Acceptance criteria

- [ ] release candidate base SHA와 OpenAPI v1 baseline을 작업 시작 전에 고정하고 모든 evidence·artifact가 같은 candidate SHA를 가리킨다.
- [ ] 전체 journey가 deterministic fixture에서 `Sign in with Apple/session 복구 → 사진 없음·사진 개인 기록 → private 사진 업로드/complete → Today 조회 → 상세 수정·삭제 → group 생성·초대·가입·멤버 관리 → visible/hidden 공유 → 그룹 사람별 상세 → 보관함 날짜 상세 → My summary → 로그아웃·재로그인 → 재인증 계정 탈퇴` 순서와 각 실패·재시도를 통과한다.
- [ ] OpenAPI parser/example/provider/Swift consumer gate가 모든 operation·error를 통과하고, Stage 10 baseline 대비 기존 v1 path/method/status/field 의미 삭제, optional→required, enum 축소 또는 type 변경을 거부한다.
- [ ] 모든 Flyway migration이 빈 PostgreSQL 18에 clean apply되고 Stage 9 schema/data fixture에서 current schema로 upgrade되며 account·Snap·group·share·media 불변 규칙을 보존한다.
- [ ] current migration 적용 뒤 즉시 이전 server artifact가 자신이 아는 route로 boot/read/write smoke를 통과하고, rollback은 이전 immutable image와 동일 secret만 복원하며 DB down migration을 실행하지 않는다.
- [ ] 서버 전체 test·bootJar·immutable Docker image build와 fake normal deploy/health-failure rollback test가 한 번의 release gate에서 모두 green이다.
- [ ] iPhone 16/iOS 18.5의 Swift unit/integration와 모든 MVP XCUITest가 green이고 release configuration에는 launch scenario parser, fake credential, fixture JSON 또는 debug endpoint가 포함되지 않는다.
- [ ] visual manifest가 Stage 1~9 핵심 화면 전체의 exact source node allowlist·393x852 reference·checksum을 빠짐없이 포함하고 app/reference/overlay/diff/report가 각 bounded threshold를 통과한다. 핵심 invite/share/visible-hidden group 화면이 `design-gated`이면 release readiness도 blocked이며, source 없는 보조 오류 상태를 임의 baseline으로 채우지 않는다. 누락·checksum drift·자동 baseline 갱신은 release를 실패시킨다.
- [ ] 모든 사용자 action과 정보성 이미지가 VoiceOver label/trait/순서를 가지며 color만으로 상태를 구분하지 않고 interactive target은 44x44pt 이상이다.
- [ ] 지원 Dynamic Type 기본·AX5 크기에서 핵심 값과 primary/destructive action이 잘리거나 겹치지 않고 scroll 또는 재배치로 도달 가능하다.
- [ ] Reduce Motion에서 canvas 낙하·충돌·장식 전환은 짧은 fade/scale 또는 정적 배치로 대체되고 기록·공유 완료 의미와 focus 이동은 유지된다.
- [ ] versioned representative dataset과 동일 local container protocol이 API latency distribution과 archive·group·summary bounded query 수를 raw report로 남긴다. 500ms는 현재 origin 재검토 진단 기준이며, 재현 가능한 release 차단 budget으로 별도 승인·canonical화하기 전에는 단일 CI p95만으로 candidate를 실패시키지 않는다.
- [ ] iOS cold launch/session restore, Home 첫 content, record sheet와 archive/group navigation의 Instruments/ETTrace evidence에 main-thread synchronous network·image decode, hang 또는 지속 hitch가 없고 Home object settle은 canonical 0.6~1.2초 안에 끝난다.
- [ ] security regression이 owner isolation, invalid/revoked session, invite replay/capacity, hidden group의 amount-derived field 부재, expired/oversize/checksum-failed media, account cascade와 post-delete access denial을 검증한다.
- [ ] repository tracked files와 built JAR/app/Docker archive/history scan에 private key, password, Neon/R2/Apple/SSH token 또는 runtime `.env`가 없고 GitHub Secret Scanning·Push Protection은 enabled이며 unresolved valid alert가 0이다.
- [ ] release readiness report가 candidate SHA, toolchain, test/visual/performance/security 결과, OpenAPI/migration compatibility, known limitations와 exact rollback target을 기록하고 모든 실패를 닫기 전 candidate를 ready로 표시하지 않는다.
- [ ] 이 작업은 외부 환경을 변경하지 않으며 release candidate ready는 deployment 완료나 Apple/TestFlight activation을 의미하지 않는다.

## Test seam

- TDD journey seam: stage별 isolated test는 유지하고 전체 stateful journey가 찾는 adapter/transaction/state gap을 실패 테스트로 먼저 재현한다.
- compatibility seam: frozen OpenAPI v1과 Stage 9 migration/image를 held-out baseline으로 두고 breaking schema와 incompatible migration fixture가 gate를 실제 red로 만드는지 검증한다.
- release build seam: Debug-only launch environment·fixture symbol 중 하나를 의도적으로 Release에 노출했을 때 static/binary validator가 실패하는 negative test를 둔다.
- accessibility seam: XCUITest identifier/label/target matrix와 AX5/Reduce Motion screenshot scenario를 고정하고 사람이 VoiceOver traversal evidence를 함께 확인한다.
- performance seam: versioned seed size, warm-up, request count/concurrency, device/runtime와 threshold를 report에 고정해 수치가 재현 가능하게 한다.
- security seam: 권한 matrix와 secret canary fixture가 각각 application test·scanner를 red로 만드는 held-out 검증을 둔다.
- 긴 테스트는 stage별 targeted fix 동안 반복하지 않고 candidate 변경 묶음이 닫힐 때 full server/native/UI/visual/performance/security gate를 실행한다. full gate 실패는 해당 targeted test를 먼저 고친 뒤 다시 전체 실행한다.

## Verification

```text
cd server; .\gradlew.bat test --no-daemon --console=plain
cd server; .\gradlew.bat bootJar --no-daemon --console=plain
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1
bash server/scripts/test-docker-deployment.sh
bash ios/scripts/test.sh
bash ios/scripts/capture-visual-baseline.sh
git diff --check
```

구현 중 위 기본 명령 외에 다음 결정론적 release runner를 먼저 작성하고 각각 red fixture를 통과시킨 뒤 AC evidence로 사용한다. 존재하기 전에는 실행했다고 기록하지 않는다.

```text
bash scripts/release/validate-openapi-compatibility.sh
bash scripts/release/test-migration-compatibility.sh
bash scripts/release/validate-release-fixture-isolation.sh
bash scripts/release/test-performance-protocol.sh
bash scripts/release/scan-release-secrets.sh
bash ios/scripts/test-accessibility-matrix.sh
bash ios/scripts/capture-ettrace-evidence.sh
gh api repos/{owner}/{repo} --jq '.security_and_analysis | {secret_scanning: .secret_scanning.status, push_protection: .secret_scanning_push_protection.status}'
gh api --method GET -f state=open repos/{owner}/{repo}/secret-scanning/alerts
gh api repos/{owner}/{repo}/rulesets
```

repository security 결과는 `secret_scanning=enabled`, `push_protection=enabled`이고 open alert 배열이 비어 있을 때만 green이다. ruleset 응답은 main의 PR·linear history·conversation resolution과 force-push/delete 금지 계약을 별도로 판정한다.

## Evidence

- 실행 명령: 구현 전 Stage 1~9 work item·canonical architecture/CI/infra contract 확인, candidate 고정 후 위 명령과 release report 경로 기록 예정
- 결과: 2026-08-13 작업 항목 작성 시점에는 계획만 고정했으며 release readiness나 배포 완료를 주장하지 않음
- 리뷰: 사용자가 전체 MVP 구현·테스트와 기능별 완료 후 장기 테스트를 포괄 승인함

## Agent rules impact

- 영향 여부: yes
- 근거: release gate, OpenAPI compatibility, migration rollback, 전체 iOS 검증과 security/performance 명령이 프로젝트 완료 절차를 확장한다.
- 처리 결과: release 기준 문서와 실제 검증 script를 먼저 갱신한 뒤 `AGENTS.md` 현재 단계·명령·승인 경계를 동기화한다. 외부 배포 승인 경계는 완화하지 않는다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: candidate base를 고정한 incremental update 후 전체 changed flow를 standard detail로 최종 재검토
- base: Stage 10 시작 시 고정한 release candidate 이전 SHA
- risk: high (whole-product regression, contract/migration compatibility, security and release fixture isolation)
- findings와 처리 결과: graph finding을 원 stage AC와 테스트에 연결하고 actionable finding은 TDD hotfix→targeted test→incremental reupdate→full release gate 순서로 닫는다.

## Decisions and risks

- 새 orchestration framework를 만들지 않고 기존 Gradle, Xcode, visual, Docker validation entrypoint를 얇은 release report로 묶는다.
- 성능은 CI 시간 한 번의 우연한 수치가 아니라 versioned protocol과 raw result를 남긴다. canonical 500ms exit threshold를 넘으면 무료 origin 적합성 결정을 다시 연다.
- compatibility는 자동 DB down migration이 아니라 expand-first schema와 이전 image의 제한된 rollback window로 보장한다.
- secret scanner가 단순 test canary를 잡는 것과 실제 credential alert를 구분하되 실제 alert를 allowlist로 숨기지 않는다.
- release candidate는 source와 artifact의 검증 상태이며 WORK-034의 외부 development smoke 승인이나 Apple activation을 선취하지 않는다.

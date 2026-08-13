---
id: WORK-022
status: verify
depends_on: [WORK-019]
owner: codex
---

# OpenAPI 3.1 semantic contract 하네스

## Intent

canonical `contracts/openapi/moneysnap-v1.yaml`의 문법·reference·schema와 서버/iOS HTTP fixture가 기능 단계마다 함께 깨지도록 결정론적 contract gate를 만든다.

## In scope

- Gradle test에서 실행되는 pinned OpenAPI 3.1 parser/validator
- unresolved reference, parser warning/error, duplicate operation ID와 `/api/v1` base contract 검사
- request·success·error example의 schema validation
- 서버 HTTP 통합 테스트의 exact field set과 iOS decode fixture를 canonical example에 연결
- server CI와 repository 정적 계약에 validation task 연결
- 인증·Snap·media·group·archive operation을 단계별로 추가할 수 있는 최소 패턴
- repository의 `contracts/examples/v1/**` canonical JSON fixture를 OpenAPI·서버 provider test·iOS consumer test가 함께 사용

## Out of scope

- OpenAPI 기반 server stub·Swift client code generation
- 별도 schema registry, gateway, mock server 또는 새로운 배포 서비스
- live production endpoint 호출
- tolerant/strict JSON 정책을 validator가 임의로 결정하는 일
- Gradle code generation task나 별도 schema registry

## Acceptance criteria

- [x] OpenAPI 3.1 document가 parser warning·error와 unresolved `$ref` 없이 통과한다.
- [x] canonical server base는 실제 route와 같은 `/api/v1`이고 operation ID는 중복되지 않는다.
- [x] 각 operation의 request·success·모든 문서화된 error example이 해당 schema를 통과한다.
- [x] 공용 ErrorResponse는 정확히 `code`, `correlationId`를 요구하고 enum drift를 CI가 거부한다.
- [ ] runtime HTTP integration test가 success/error JSON의 exact field set을 검증하고 canonical example과 iOS fixture가 같은 wire shape를 사용한다. (server green, macOS native consumer pending)
- [x] auth와 신규 Snap contract 중 하나를 의도적으로 깨뜨리면 validator가 red가 되는 held-out 검증을 기록한다.
- [x] parser dependency는 버전을 고정하고 code generation·runtime dependency로 production artifact에 포함하지 않는다.
- [ ] canonical example은 repository 밖 URL을 참조하지 않고 `contracts/examples/v1/**` 안의 한 벌만 서버·iOS 테스트 resource로 사용한다. (containment/server/static green, macOS resource loading pending)

## Test seam

- parser seam: repository root의 canonical YAML을 test resource가 아닌 실제 path에서 읽는다.
- provider seam: MockMvc integration test의 exact JSON/status/header 계약
- consumer seam: Swift URLProtocol test가 test resource로 포함한 canonical example 파일 자체를 decode/encode한다.
- negative seam: unresolved `$ref`, 잘못된 example 또는 duplicate operation ID fixture가 validator failure를 만든다.

## Verification

```text
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.contract.OpenApiContractTests" --no-daemon --console=plain
cd server; .\gradlew.bat test --no-daemon --console=plain
powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1
git diff --check
```

## Evidence

- 실행 명령:
  - `cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.contract.OpenApiContractTests" --no-daemon --console=plain`
  - `cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.contract.OpenApiContractTests" --tests "com.ansandy.moneysnap.identity.ApiErrorResponseTests" --no-daemon --console=plain`
  - `cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.identity.AuthenticationHttpIntegrationTests" --tests "com.ansandy.moneysnap.identity.AccountDeletionHttpIntegrationTests" --tests "com.ansandy.moneysnap.identity.AppleAccountEventHttpIntegrationTests" --no-daemon --console=plain`
  - `cd server; .\gradlew.bat test --no-daemon --console=plain`
  - `cd server; .\gradlew.bat bootJar --no-daemon --console=plain`
  - `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1`
  - `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1`
  - `powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1`
  - `git diff --check`
- 결과:
  - 현재 YAML은 parse 가능한 5개 identity path지만 semantic OpenAPI validator와 provider/consumer example gate가 없음
  - RED: `compileTestJava`가 존재하지 않는 `OpenApiContractValidator` interface 때문에 의도대로 실패함
  - RED: example 없는 JSON request, remote HTTP example, invalid auth `date-time`, runtime error enum drift가 각각 targeted test에서 실패함
  - GREEN: test-only Swagger Parser `2.1.45`와 NetworkNT validator `3.0.6`으로 parser/base/operation ID, real-path external fixture containment, Draft 2020-12 schema와 format assertion, ErrorResponse exact shape/nonempty enum을 검증함. package-local `ApiErrorResponseTests`가 runtime `ApiErrorCode`와 OpenAPI enum의 정확한 동등성을 compile-time package seam에서 검증함.
  - GREEN: unresolved `$ref`, duplicate operation ID와 synthetic Stage 3 Snap amount mutation negative seam이 통과함. production Snap schema/operation은 Stage 3이 같은 pattern으로 추가한다.
  - GREEN: canonical identity JSON 한 벌을 OpenAPI externalValue, server HTTP provider test와 iOS test resource/consumer test에 연결함. request 추가 필드는 기존 tolerant decoding 정책을 유지함.
  - GREEN: targeted `OpenApiContractTests` 9개와 `ApiErrorResponseTests`, 인증 HTTP integration 3개 class가 통과함.
  - GREEN: Docker engine ready 상태의 server full test 18 suites/103 tests, failure/error/skip 0, 52초 통과. `bootJar` 8초 통과.
  - GREEN: iOS project/visual baseline, CI/CD repository validator와 `git diff --check` 통과.
  - REMOTE BOUNDARY: iOS canonical fixture consumer test는 Windows에서 Xcode 실행 불가. push 후 GitHub macOS native lane에서 확인 필요
- 리뷰: 2026-08-13 사용자가 held-out contract 하네스와 test-only dependency·iOS test resource·CI 고정 앵커 변경을 명시적으로 승인함

## Agent rules impact

- 영향 여부: yes
- 근거: 서버 전체 테스트와 CI가 실행하는 canonical API contract gate가 추가된다.
- 처리 결과: `AGENTS.md`에 test-only pinned dependency와 targeted verification을, README/architecture/CI 문서에 동일 canonical fixture contract를 동기화함.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: `get_minimal_context` → incremental update(32 files, 34 nodes/507 edges) → `get_minimal_context` → standard `detect_changes`
- base: `e3f3656` (승인된 docs-only MVP 계획 커밋 직후의 고정 기준점; 구현 시작 SHA는 `393d6d7`)
- risk: medium (held-out evaluator integrity, wire compatibility)
- findings와 처리 결과: graph의 31개 test gap은 변경 대상 자체가 test source인데 Swift/Java test helper 일부를 production node로 분류한 보조 도구 false positive다. server 103 tests는 green이고 Swift consumer는 macOS native lane 대기 상태로 명시했다. 독립 spec/security/correctness 재검토 finding 0; 공개 범위가 불필요했던 test helper 두 메서드는 private로 축소했다.

## Decisions and risks

- 2026-08-13 사용자 명시 승인 범위에서 test-only dependency와 canonical validation anchor를 변경한다.
- Swagger Parser 공식 문서가 2.1.0+ OpenAPI 3.1 parsing/validation/resolution을, NetworkNT 공식 문서가 3.x Java 17+/Jackson 3와 Draft 2020-12/format assertion을 지원함을 확인하고 `2.1.45`, `3.0.6`을 정확히 고정했다.
- 기본 Gradle `test` source set 안에서 실행해 별도 task 없이 schema·example drift를 실패시키는 가장 작은 하네스를 유지한다.
- 별도 Gradle task, code generation, production abstraction과 실제 Snap production contract는 추가하지 않는다.

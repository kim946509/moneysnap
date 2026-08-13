---
id: WORK-020
status: ready
depends_on: [WORK-018]
owner: codex
---

# iOS MVP visual·UI test 공통 하네스 기반

## Intent

Home·My로 검증되는 확장 가능한 393x852 visual evidence·XCUITest 기반을 먼저 만들고, 각 기능 stage가 자기 화면과 흐름을 독립적으로 추가할 수 있게 한다.

## In scope

- `MoneySnapUITests` target과 app-hosted deterministic launch scenario
- DEBUG에만 존재하는 fail-closed `home`, `my` scenario allowlist, fake auth/session과 Home fixture adapter의 release 격리
- 기존 Home/My Figma node ID·393x852 reference·checksum manifest의 확장 가능한 순서 계약
- 한 번 build·install한 app으로 Home/My를 순차 capture하는 macOS runner
- Home/My 최소 UI smoke/navigation test와 visual artifact를 실행·업로드하는 GitHub Actions 계약
- Windows 정적 validator가 target, node, checksum, allowlist, workflow 연결을 검증

## Out of scope

- 제품 화면 구현이나 서버 기능
- My 화면의 현재 정적 Figma content를 production API에 연결하는 일; WORK-032가 소유한다.
- 기록 입력, Snap 상세, 그룹, 공유, 보관함의 scenario·XCUITest·reference·threshold; 각 기능 stage가 소유한다.
- 기존 Home/My threshold 완화
- 실제 Apple 로그인, 실제 사진 보관함·카메라, live Neon·R2 호출
- device signing, archive, TestFlight, 배포
- Figma에 없는 화면을 임의 reference로 만드는 일

## Acceptance criteria

- [ ] `MoneySnapUITests` target이 iPhone 16/iOS 18.5 Simulator에서 Home과 My 최소 flow를 실행한다.
- [ ] visual launch parser, allowlist, fake auth/session과 Home fixture adapter 전체가 하나의 `#if DEBUG` support 경계 안에 있고 release build에는 존재하지 않는다. 일반 launch는 fixture가 아닌 명시적 live/unavailable adapter를 사용한다.
- [ ] 비어 있지 않은 unknown visual scenario는 live path로 fallback하지 않고 DEBUG launch를 fail-closed하며, 환경 변수가 없을 때만 정상 live path를 사용한다.
- [ ] manifest의 ordered scenario 목록과 exact Figma node ID, 393x852 PNG, SHA-256 집합이 일치한다.
- [ ] capture runner는 app을 한 번 build·install하고 Home/My별 reference/app/overlay/diff/report를 모두 생성한다. 한 scenario가 threshold를 넘더라도 나머지 evidence를 만든 뒤 마지막에 non-zero로 종료한다.
- [ ] 기존 Home/My MAE `0.05`, mismatched pixel ratio `0.43` 상한을 완화하지 않는다.
- [ ] Home/My fixture가 외부 Apple·Neon·R2와 credential 없이 재현된다.
- [ ] Windows validator가 UI-testing target·scheme, DEBUG gate, scenario/checksum 집합, build-once runner와 workflow 단일 호출을 검증한다.
- [ ] macOS native lane이 unit+UI test와 Home/My visual threshold를 모두 통과한다.

## Test seam

- static red seam: 현재 project에는 UI test target/scheme 연결이 없고 release에 visual fixture가 노출되며 manifest ordered scenario 배열이 없고 workflow가 runner를 두 번 호출해 두 번 build/install한다.
- functional seam: launch environment로 고정한 fake adapter를 통해 Home 표시와 My 이동을 XCUITest가 관찰한다.
- visual seam: 기존 Home `9:2`, My `77:798` reference와 app screenshot을 동일 393x852 viewport에서 비교한다.
- extension seam: 각 후속 stage가 manifest scenario·reference·accessibility identifier·XCUITest를 같은 패턴으로 추가한다.

## Verification

```text
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1
bash ios/scripts/test.sh
bash ios/scripts/capture-visual-baseline.sh
git diff --check
```

## Evidence

- 실행 명령:
  - current harness inspection
- 결과:
  - `MoneySnapUITests` target/scheme 연결 없음
  - `AuthenticationSession.visualFixture`와 Home fixture adapter가 release source에 남아 있음
  - manifest에 explicit ordered scenarios가 없고 workflow가 Home/My runner를 각각 호출함
  - Figma Starter MCP 호출 한도로 category·amount component 추가 조회 대기
- 리뷰: 2026-08-13 사용자가 고정 하네스 변경을 명시적으로 승인함

## Agent rules impact

- 영향 여부: yes
- 근거: 실제 iOS 검증 명령이 실행하는 held-out scenario와 UI test gate가 확대된다.
- 처리 결과: 사용자 승인 후 기준 검증 문서와 `AGENTS.md` 명령 설명을 동기화한다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: 구현 시작 직전 HEAD를 고정하고 구현 후 iOS changed-files 기준 incremental update 예정
- base: 구현 시작 직전 고정
- risk: high (held-out evaluation integrity, release test seam exposure)
- findings와 처리 결과: 승인 후 하네스 구현 변경과 기능 소스 변경을 분리해 각각 검토한다.

## Decisions and risks

- 2026-08-13 사용자 명시 승인 범위에서 project target, manifest, allowlist와 workflow를 변경한다.
- My의 정적 Figma content 자체는 이번 하네스의 release fixture 격리 범위가 아니며, WORK-032가 실제 account summary로 교체한다.
- UI test target은 `com.apple.product-type.bundle.ui-testing`과 `TEST_TARGET_NAME = MoneySnap`을 사용하고 app-hosted unit-test의 `TEST_HOST`/`BUNDLE_LOADER`를 복제하지 않는다.
- manifest의 명시적 `scenarios: [home, my]`와 작은 DEBUG enum만 사용하며 scenario registry, code generation, 새 snapshot dependency나 XCTestPlan을 추가하지 않는다.
- Figma reference를 확보하지 못한 scenario는 visual 완료로 표시하지 않는다.
- system PhotosPicker·camera의 실제 device 검증과 deterministic fixture UI 검증을 구분해 증거를 기록한다.
- 기능 scenario를 이 기반 작업에 미리 넣지 않으며 Stage 10에서 전체 MVP allowlist 완결을 확인한다.

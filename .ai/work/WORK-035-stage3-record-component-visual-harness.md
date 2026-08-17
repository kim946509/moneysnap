---
id: WORK-035
status: active
depends_on: [WORK-020]
owner: codex
---

# Stage 3 기록 component 시각 하네스

## Intent

공식 Figma 기록 component를 전체 화면 parity로 과장하지 않으면서, 결정론적 DEBUG 기록 상태의 원본 provenance와 지정 crop 비교를 macOS 시각 증거로 검증한다.

## In scope

- visual manifest screen별 선택적 `comparisonCrop` 계약
- `record-category` Figma node `108:465`, crop `x=0, y=604, width=393, height=248`
- `record-amount` Figma node `108:549`, crop `x=0, y=460, width=393, height=392`
- 공식 393x852 Figma PNG와 SHA-256 고정
- crop scenario의 전체 reference·app screenshot provenance 보존과 지정 영역 comparison artifact·report 생성
- 외부 Apple·Neon·R2 없이 category·amount 상태를 재현하는 DEBUG 전용 deterministic record scenario
- Windows 정적 계약, macOS native UI test와 393x852 visual evidence 검증

## Out of scope

- `home`, `my` reference, checksum, full-frame 비교 방식이나 threshold 변경
- Figma에 없는 사진 없는 기록 전체 화면의 pixel parity 주장 또는 임의 reference 생성
- production 기록 동작, API 계약, 제품 UI 자체의 변경
- 새로운 snapshot dependency, scenario registry 또는 code generation
- Apple signing, 실제 기기, 배포와 live 외부 서비스 호출

## Acceptance criteria

- [ ] manifest는 screen별 `comparisonCrop`을 선택적으로 허용하고, 필드가 없는 기존 `home`·`my`는 현재 full-frame 비교와 threshold를 그대로 사용한다.
- [ ] `record-category`는 node `108:465`, official PNG SHA-256 `ada9814549f1bab323cbfc4040379156ce0757f41b9f50fc4f75927c5fafa47f`, crop `(0,604,393,248)`을 정확히 사용한다.
- [ ] `record-amount`는 node `108:549`, official PNG SHA-256 `26e378b06fa7539bfbb8ff4a3124678853b3e87a8f4e15399fefbf2b0eeb14ac`, crop `(0,460,393,392)`을 정확히 사용한다.
- [ ] crop은 393x852 viewport 경계 안의 양의 정수 사각형이어야 하며, 누락·범위 초과·잘못된 타입·reference checksum drift를 정적 validator가 거부한다.
- [ ] capture runner는 record scenario의 전체 393x852 reference와 app screenshot을 provenance로 보존하고, 지정 crop만 비교한 app/reference/overlay/diff/report evidence를 생성한다.
- [ ] crop report는 scenario, Figma node, 원본 checksum, crop 좌표와 실제 비교 지표를 식별할 수 있고 기존 공통 threshold를 완화하지 않는다.
- [ ] DEBUG `record-category`·`record-amount` scenario는 동일 입력에서 각각 category 선택 상태와 amount 입력 상태를 결정론적으로 재현하며 release build와 정상 launch path에 노출되지 않는다.
- [ ] native UI test가 두 deterministic scenario를 열어 기대 단계와 주요 accessibility marker를 확인한다.
- [ ] macOS visual runner가 기존 `home`·`my` full-frame evidence와 두 record crop evidence를 한 실행에서 모두 생성하고 전체 threshold를 통과한다.
- [ ] 완료 증거는 record component crop parity로만 표현하며 사진 없는 기록 전체 화면이 Figma와 일치한다고 주장하지 않는다.

## Test seam

- static RED seam: crop-aware manifest validation이 없거나 좌표·checksum을 변형해도 통과하는 현재 경계를 먼저 실패시킨다.
- parser RED seam: `comparisonCrop`의 누락 가능한 정상 screen과 malformed/out-of-bounds crop을 각각 허용·거부하는 계약을 고정한다.
- DEBUG scenario seam: 외부 credential 없이 category·amount 단계를 직접 재현하고 unknown scenario는 기존처럼 fail-closed한다.
- native seam: XCUITest가 두 scenario의 단계 marker와 핵심 action을 관찰한다.
- visual seam: 전체 393x852 원본은 provenance로 남기고 node `108:465`와 `108:549`의 지정 crop pixels만 Figma reference와 비교한다.
- regression seam: crop이 없는 `home`·`my` artifact 구조, full-frame 계산과 threshold가 변경되지 않았음을 같은 runner에서 확인한다.

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
  - `git diff --check -- .ai/work/WORK-035-stage3-record-component-visual-harness.md`
- 결과:
  - 2026-08-13 사용자가 Stage 3 기록 component에 한정한 manifest·capture 하네스 변경을 명시 승인했다.
  - 공식 reference는 node `108:465`와 `108:549`의 393x852 PNG이며 위 SHA-256과 crop을 승인 기준으로 고정했다.
  - work item 문서의 whitespace 검증은 exit 0이다.
- 리뷰: 구현은 static RED→GREEN, native UI, visual artifact 순으로 검증하고 `WORK-021`의 미완료 시각 AC만 unblock한다.

## Agent rules impact

- 영향 여부: no
- 근거: 기존 `bash ios/scripts/capture-visual-baseline.sh` 명령과 Figma source-of-truth·393x852·DEBUG 격리 불변 규칙은 유지되고, 이번 변경은 두 scenario의 선택적 crop 표현만 구체화한다.
- 처리 결과: `AGENTS.md` 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: 구현 시작 고정 기준점에서 incremental update 예정
- base: 구현 시작 시 고정
- risk: medium (held-out visual evaluator와 DEBUG/release 격리 경계)
- findings와 처리 결과: 구현 후 standard detail로 manifest parser, runner crop 계산, scenario 격리와 테스트 공백을 검사하고 actionable finding은 TDD로 수정한다.

## Decisions and risks

- `comparisonCrop`은 screen별 optional field로 두며 crop이 없는 기존 scenario의 의미를 바꾸지 않는다.
- full screenshot은 출처와 재현 상태를 증명하는 provenance이고, record scenario의 parity 판정 범위는 승인된 component crop뿐이다.
- 전체 no-photo 화면에 대응하는 공식 Figma frame이 없으므로 crop 바깥 영역은 시각 합격·불합격 판정에 사용하지 않는다.
- runner와 validator의 기존 public command를 유지하고 별도 crop 전용 실행 명령이나 중복 하네스를 만들지 않는다.
- `WORK-035`는 `WORK-020` 기반을 확장하며 완료 시 `WORK-021`의 record visual AC를 unblock한다. 순환 의존성을 만들지 않는다.

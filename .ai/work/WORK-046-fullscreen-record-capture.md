---
id: WORK-046
status: verify
depends_on: [WORK-042]
owner: unassigned
---

# 라이브 카테고리·금액 입력을 화면 전체로

## Intent

카테고리와 금액을 함께 입력하는 라이브 기록 화면이 `.large` 시트 위 홈 여백 없이 화면 전체를 쓰게 한다.

## In scope

- 라이브 combined 기록을 `fullScreenCover`로 표시
- 상단 핸들로 아래로 내려 닫기
- visual CI staged `record-category`/`record-amount`는 기존 시트 높이 유지
- UI_GUIDE·SCREEN_STRUCTURE·USER_FLOW·SERVICE_POLICY의 라이브 입력 높이 문구 동기화

## Out of scope

- Figma staged 프레임 PNG 재촬영
- 공유 시트 높이
- 사진 source 단계 레이아웃 재설계
- TestFlight 수동 재실행(main iOS CI 성공 시 기존 CD)

## Acceptance criteria

- [ ] 라이브/feature 기록 화면은 윈도우 높이의 98% 이상을 차지하고 상단 여백이 거의 없다
- [ ] visual 시나리오 `record-category`/`record-amount`는 staged 시트로 유지한다
- [ ] 저장하지 않은 입력은 상단 핸들 닫기로 취소할 수 있다
- [ ] 공유 그룹이 있으면 기록 화면이 닫힌 뒤에 share sheet가 열린다
- [ ] Windows iOS 프로젝트 정적 검증을 통과한다

## Test seam

- `MoneySnapUITests.testRecordFeatureFlowFromCenterAddReturnsToHomeOnce`의 기록 화면 frame
- visual UITest `record-category`/`record-amount`는 기존 identifier를 유지

## Verification

```text
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
git diff --check
```

## Evidence

- 실행 명령:
  - `git diff --check` → 통과
  - `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1` → visual baseline probe 실패. `capture-visual-baseline.sh`가 이 작업 트리에서 CRLF라 `xcodebuild` 한 줄 계약 정규식이 0건. 이번 diff와 무관한 Windows checkout 이슈.
  - GitHub-hosted `macos-15` iOS CI `32575620739` → Swift native tests + `bash ios/scripts/capture-visual-baseline.sh` 성공. artifact `ios-visual-evidence`. staged `record-category` (`108:465`)와 `record-amount` (`108:549`) visual 유지.
- 결과: 라이브 combined 기록은 `fullScreenCover`로 화면 전체를 쓰고, staged visual 시나리오는 기존 시트 높이를 유지한다. UITest는 기록 화면이 윈도우를 채우는지를 검증한다.
- 리뷰: CodeRabbit source 단계 닫기 핸들을 공통 chrome으로 옮겼다. code-review-graph MCP는 이 세션 도구 목록에 없어 skipped.

## Agent rules impact

- 영향 여부: no
- 근거: UI 가이드와 화면 구조만 바뀌고 AGENTS.md의 스택·승인 경계·검증 명령은 그대로다.
- 처리 결과: 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
- base: origin/main `30fd160`
- risk: low
- findings와 처리 결과: 이 세션의 사용 가능 도구에 `code-review-graph` MCP가 없다. 그래프 결과는 보조 증거이며 iOS CI UITest·visual capture가 이 변경의 검증을 소유한다.

## Decisions and risks

- `.large` detent는 홈이 위에 남는다. 라이브 combined만 `fullScreenCover`를 쓰고 staged visual은 시트를 유지한다.
- native iOS 테스트는 Windows에서 실행하지 못하고 GitHub-hosted iOS CI가 소유한다.

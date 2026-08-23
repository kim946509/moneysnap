---
id: WORK-047
status: verify
depends_on: [WORK-046, WORK-044]
owner: unassigned
---

# 기록 시트 UX와 홈 물리 안정화

## Intent

사진 선택은 낮은 시트로 두고, 카테고리·금액 입력은 더 넓은 화면에서 안내와 함께 끝내며, 저장은 버튼을 붙잡지 않고, 여러 장 기록과 홈 물리 낙하가 안정적으로 보이게 한다.

## In scope

- 사진 소스 시트 약 30% 높이, 이후 카테고리+금액은 large detent
- 카테고리 미선택 안내
- 키패드에서 완료 분리, C로 금액 초기화
- 완료/다음 버튼에 `저장 중`을 표시하지 않음
- 다음 사진으로 넘어갈 때 금액·카테고리 초기화
- 미리보기 사진을 중앙에 크게
- 홈 물리는 기록하기 버튼 위 영역만, 3개 이상에서도 폭발하지 않음
- 새 기록은 위에서 떨어져 기존 오브젝트와 부딪힘
- visual Home `9:2` staged rest 3장은 유지

## Out of scope

- Figma staged record PNG 재촬영
- 그룹 캔버스 물리
- 서버 record API 변경

## Acceptance criteria

- [ ] 라이브 사진 선택 시트는 화면의 약 30%만 차지한다
- [ ] 카테고리+금액 단계는 large detent이고 카테고리 미선택 시 안내 문구가 있다
- [ ] 키패드 하단은 `C`·`0`·지움이며 완료/다음은 키패드 밖 버튼이다
- [ ] 완료/다음 라벨은 `저장 중`이 되지 않는다
- [ ] 여러 장 기록에서 다음 사진으로 넘어가면 금액과 카테고리가 비어 있다
- [ ] 미리보기 사진은 중앙 큰 정사각이다
- [ ] 물리 바닥은 기록하기 버튼 위이고, 새 항목은 천장 근처에서 떨어진다
- [ ] visual Home은 기존 3장 rest 좌표를 유지한다
- [ ] Windows iOS 프로젝트 정적 검증을 통과한다

## Test seam

- `SnapCaptureModel` 다음 사진 draft 초기화, `clearAmount`, submit 라벨
- `TodayCanvasPlacement` 물리 바닥·낙하·다수 크기
- `MoneySnapUITests` 기록 완료 버튼과 카테고리 안내

## Verification

```text
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
git diff --check
```

## Evidence

- 실행 명령:
  - `git diff --check` → 통과
  - Windows native iOS test는 실행하지 못함. GitHub-hosted iOS CI가 검증한다.
- 결과: 소스 시트 30%, 카테고리 안내, C/완료 분리, 다음 사진 draft 초기화, 물리 바닥을 기록하기 위로 두고 다수 오브젝트 원형 바디로 안정화.
- 리뷰: code-review-graph MCP 없음, skipped.

## Agent rules impact

- 영향 여부: no
- 근거: UI 가이드와 화면 구조만 바뀌고 AGENTS.md의 스택·승인 경계·검증 명령은 그대로다.
- 처리 결과: 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
- base: origin/main
- risk: medium
- findings와 처리 결과: code-review-graph MCP가 이 세션에 없어 skipped

## Decisions and risks

- 라이브 기록은 다시 sheet detent를 쓴다. 소스 30%는 fullScreenCover로 만들 수 없다.
- 저장 실패 재시도는 시트가 열려 있는 동안만 시트에서 처리한다. 마지막 장 성공 경로는 완료 라벨을 바꾸지 않는다.
- 물리 폭발의 원인은 3장 고정 박스에 강한 impulse와 freeze였다. 라이브는 금액 크기 원형 바디와 감쇠로 바꾼다.

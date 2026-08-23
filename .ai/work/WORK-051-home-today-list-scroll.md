---
id: WORK-051
status: active
depends_on: [WORK-050]
owner: unassigned
---

# 오늘 소비 목록을 전부 세로 스크롤한다

## Intent

홈 `오늘 소비`가 오늘 개인 Snap을 2건에서 자르지 않고, 많으면 아래로 스크롤해 나머지를 본다.

## In scope

- today 저널의 recent ID 매핑
- 라이브 Home 2열 목록과 세로 스크롤
- Figma `9:2` visual 2건 고정 유지

## Out of scope

- 보관함 목록
- 홈 물리 튕김
- featured 캔버스 개수
- Figma PNG baseline 재촬영

## Acceptance criteria

- [ ] today 응답의 모든 Snap이 recent 목록에 들어간다
- [ ] 라이브 Home에서 첫 화면 아래 건을 아래로 스크롤해 탭할 수 있다
- [ ] visual Home `9:2`는 기존 2건 고정 좌표를 유지한다

## Test seam

- `SnapJournalClientTests` 4건 today 매핑
- UITest `testHomeTodayListScrollsBeyondTheFirstTwoSnaps`

## Verification

```text
git diff --check
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
```

## Evidence

- 실행 명령: `git diff --check`
- 결과: clean
- `ios\scripts\validate-project.ps1`: PBX object IDs OK. visual baseline regression probe failed on reviewed manifest (Windows visual contract, 이 변경 파일과 무관한 기존 실패)
- 리뷰: GitHub-hosted iOS CI가 Swift Testing·XCUITest를 실행한다.

## Agent rules impact

- 영향 여부: no
- 근거: 홈 목록 표시만 고친다. 스택·보안·승인 경계·검증 명령은 그대로다.
- 처리 결과: 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
- base: origin/main
- risk: low
- findings와 처리 결과: 이 세션에 `code-review-graph` MCP가 없어 skip.

## Decisions and risks

- visual `9:2`는 2건 HStack 오프셋을 유지한다. 라이브만 전체 목록과 페이지 스크롤을 쓴다.
- 2열·150×46·간격 28은 Figma 첫 줄을 유지한다.

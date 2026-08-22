---
id: WORK-043
status: verify
depends_on: [WORK-031]
owner: unassigned
---

# 보관함 UI를 Figma 달력 크롬에 맞춘다

## Intent

보관함이 Home/My와 같은 Money Snap 화면 언어의 월 달력이 되게 해서, 지금 보이는 시스템 그리드+리스트와 Figma `77:681`의 차이를 줄인다.

## In scope

- 요일 정렬된 월 달력, 기록 날짜 marker, 선택 날짜, 이전/다음 월
- Home/My와 같은 타이틀 크롬과 날짜별 Snap 행
- 월 전체 빈 상태와 선택 날짜 빈 상태를 구분
- Archive calendar/view-model 단위 테스트

## Out of scope

- Figma `77:681` 393x852 visual baseline 추가(현재 FIGMA_ACCESS_TOKEN 만료로 reference PNG를 재다운로드할 수 없음)
- 그룹 공유 Snap, 월간 차트/예산
- SpriteKit 물리 캔버스

## Acceptance criteria

- [ ] 1일이 해당 요일 칸에 놓이고 일월화수목금토 헤더가 있다
- [ ] 기록 있는 날과 선택 날이 시각적으로 다르다
- [ ] 이전/다음 월과 날짜 셀은 44pt 이상
- [ ] 화면 제목은 `Archive`이고 `screen.archive` identifier를 유지한다
- [ ] 월에 기록이 없을 때와 선택 날짜가 비었을 때 문구가 다르다
- [ ] 선택 날짜의 개인 Snap만 목록에 나오고 상세로 들어간다

## Test seam

- `ArchiveCalendar` weekday padding
- `ArchiveViewModel` occupied/selection/empty copy/loadDay

## Verification

```text
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
git diff --check
```

Windows에서는 native iOS test와 393x852 visual을 실행하지 않는다.

## Evidence

- 실행 명령:
  - `git diff --check` → 통과
  - PBX object ID validation → OK
  - `validate-project.ps1` full run은 `capture-visual-baseline.sh` CRLF로 기존 visual probe가 실패. 이번 archive 파일과 무관.
- 결과: 보관함을 Home/My 크롬의 요일 정렬 달력으로 교체. Figma `77:681` PNG는 token 만료로 재다운로드하지 못함.
- 리뷰: code-review-graph MCP 없음

## Agent rules impact

- 영향 여부: no
- 근거: 화면 구현과 UI 가이드만 바뀌고 AGENTS.md 검증 명령·스택은 그대로다.
- 처리 결과: 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
- base: n/a
- risk: medium
- findings와 처리 결과: code-review-graph MCP 없음

## Decisions and risks

- Figma token 만료로 `77:681` PNG를 재조회하지 못했다. 레이아웃은 Home `9:2` / My `77:798` 크롬과 WORK-031 달력 AC를 따른다.
- visual manifest에 archive를 넣지 않는다. reference 없이 넣으면 CI 계약이 깨진다.

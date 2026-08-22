---
id: WORK-045
status: verify
depends_on: []
owner: unassigned
---

# 마이 그룹 관리·도움말 열기

## Intent

My의 `내 그룹 관리`와 `도움말` 행이 실제로 열리게 한다. 도움말 화면이 없으면 제품 범위 안에서 만든다.

## In scope

- 내 그룹 관리 → 기존 GroupListView
- HelpTopic 기반 도움말 화면
- 닫기 가능한 sheet

## Out of scope

- 이름 편집, 프로필 사진, 알림 설정
- 새 그룹 API

## Acceptance criteria

- [ ] 내 그룹 관리는 그룹 목록·만들기·가입 화면을 연다
- [ ] 도움말은 기록/공유/그룹/보관함 안내를 보여 준다
- [ ] 앱 설정은 기존처럼 열린다
- [ ] MVP에 없는 기능을 도움말에 넣지 않는다

## Test seam

- `HelpTopic` 제목·본문이 제품 흐름을 포함하는지

## Verification

```text
git diff --check
```

## Evidence

- 실행 명령:
  - `git diff --check`
  - PBX object ID validation
- 결과: git diff --check와 PBX ID 검증 통과. Windows에서는 native iOS test를 실행하지 못함.
- 리뷰: code-review-graph MCP 없음

## Agent rules impact

- 영향 여부: no
- 근거: 화면 연결과 도움말 콘텐츠만 추가한다.
- 처리 결과: 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
- base: n/a
- risk: low
- findings와 처리 결과: code-review-graph MCP 없음

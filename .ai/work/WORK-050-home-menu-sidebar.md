---
id: WORK-050
status: active
depends_on: [WORK-049]
owner: unassigned
---

# 홈 메뉴 버튼이 사이드바를 연다

## Intent

Figma에 있는 오른쪽 원형 메뉴 버튼을 누르면 사이드바가 열려 화면을 이동한다.

## In scope

- 홈·보관함·마이 메뉴 버튼
- 사이드바: 홈, 그룹, 보관함, 마이, 도움말

## Out of scope

- 그룹 목록 화면 메뉴 버튼
- 새 화면 정보 구조

## Acceptance criteria

- [x] 메뉴 버튼이 VoiceOver와 탭으로 열린다
- [x] 사이드바에서 보관함으로 이동할 수 있다

## Test seam

- UITest `testHomeMenuOpensSidebarAndNavigatesToArchive`

## Verification

```text
git diff --check
```

## Evidence

- 실행 명령: git diff --check
- 결과: clean
- 리뷰: CI iOS

## Agent rules impact

- 영향 여부: no
- 근거: 기존 Figma chrome을 동작하게 한 것이고 탭 구조를 바꾸지 않는다.
- 처리 결과: 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
- base: main
- risk: low
- findings와 처리 결과: MCP 없음

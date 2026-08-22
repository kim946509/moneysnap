---
id: WORK-044
status: verify
depends_on: [WORK-010]
owner: unassigned
---

# Home 소비 오브젝트 SpriteKit 낙하·충돌

## Intent

여러 Snap이 있을 때 Home 캔버스 오브젝트가 위에서 떨어지고 서로 부딪혀 통통 튄 뒤 자리를 잡게 한다.

## In scope

- TodayCanvas rest seed와 drop origin
- SpriteKit 중력·충돌·감쇠, 새 항목만 낙하
- reduce-motion과 visual `home` 시나리오는 정적 Figma 좌표
- 기록하기 버튼은 물리 바디가 아님

## Out of scope

- 그룹 캔버스 물리
- 393x852 visual baseline 재촬영(정적 Home은 유지)
- 효과음

## Acceptance criteria

- [ ] 정적 rest 좌표는 기존 Figma Home featured 위치와 같다
- [ ] physics 모드에서 새 항목의 시작 y는 rest보다 위다
- [ ] reduce-motion과 visual scenario는 drop을 쓰지 않는다
- [ ] 기록하기/헤더/총액은 고정이다

## Test seam

- `TodayCanvasPlacement` rest/drop/motion policy

## Verification

```text
git diff --check
```

Windows에서는 SpriteKit runtime을 실행하지 않는다.

## Evidence

- 실행 명령:
  - `git diff --check` → 통과
  - PBX object ID validation → OK
- 결과: rest 좌표 테스트와 SpriteKit 캔버스를 추가. Windows에서는 SpriteKit runtime을 실행하지 못함.
- 리뷰: code-review-graph MCP 없음

## Agent rules impact

- 영향 여부: no
- 근거: ADR에 이미 SpriteKit이 있고 검증 명령은 그대로다.
- 처리 결과: 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
- base: n/a
- risk: medium
- findings와 처리 결과: code-review-graph MCP 없음

---
id: WORK-049
status: active
depends_on: [WORK-048]
owner: unassigned
---

# 홈 유영이 실제로 움직이게, 박스 10% 확대

## Intent

홈 오브젝트가 제자리에서 떨지 않고 천천히 떠다니며, 각 박스 크기를 약 10% 키운다.

## In scope

- 낮은 감쇠와 순항 속도로 SpriteKit 유영
- 벽에 닿으면 튕긴 뒤 계속 이동
- 라이브 physicsSize 약 10% 확대

## Out of scope

- visual Home rest 좌표
- 기록하기 버튼 크기
- 새 물리 엔진

## Acceptance criteria

- [x] 라이브 유영 감쇠가 정지를 강제하지 않는다
- [x] 순항 속도가 있고 최고 속도보다 낮다
- [x] 각 박스 physics 크기가 이전보다 약 10% 크다

## Test seam

- `TodayCanvasPlacement` float 상수와 physicsSize

## Verification

```text
git diff --check
```

## Evidence

- 실행 명령:
- 결과:
- 리뷰:

## Agent rules impact

- 영향 여부: no
- 근거: 홈 물리 튜닝과 크기만 바꾼다. 스택·보안·승인 경계는 그대로다.
- 처리 결과: 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
- base: main
- risk: low
- findings와 처리 결과: MCP 없음

## Decisions and risks

- 감쇠 3.4와 힘 1.0은 제자리 진동만 만든다. 순항 속도와 낮은 감쇠로 교체한다.

---
id: WORK-052
status: active
depends_on: [WORK-051]
owner: unassigned
---

# 홈 유영을 Bouncy Bubbles로 교체한다

## Intent

SpriteKit physics body를 제거하고, p5 Bouncy Bubbles처럼 겹치면 밀어낸 뒤 튕기고 벽에서는 그 축만 뒤집는다.

## In scope

- 직접 위치·속도 적분
- 쌍 충돌 분리와 spring 튕김
- 벽 축 반전 후 영역 안 clamp
- 거의 멈췄을 때만 순항 속도 복구

## Out of scope

- visual Home rest 좌표
- 기록하기 버튼 크기
- 오늘 소비 목록

## Acceptance criteria

- [ ] 겹친 두 토큰은 한 스텝 뒤 반지름 합 이상으로 떨어진다
- [ ] 오른쪽 벽을 넘긴 토큰은 안으로 들어오고 x 속도가 반대가 된다
- [ ] 순항 복구는 거의 멈춘 뒤에만 속도를 바꾼다

## Test seam

- `TodayCanvasDrift`

## Verification

```text
git diff --check
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
```

## Evidence

- 실행 명령: `git diff --check`
- 결과: clean
- `ios\scripts\validate-project.ps1`: PBX object IDs OK. visual baseline regression probe failed on reviewed manifest (기존 Windows 계약)
- 리뷰: GitHub-hosted iOS CI가 Swift Testing을 실행한다.

## Agent rules impact

- 영향 여부: no
- 근거: SpriteKit scene 시계는 유지하고 physics body만 뺀다. 스택 목록과 승인 경계는 그대로다.
- 처리 결과: 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
- base: origin/main
- risk: low
- findings와 처리 결과: 이 세션에 `code-review-graph` MCP가 없어 skip.

## Decisions and risks

- 1번 예시 p5 Bouncy Bubbles: collide spring 0.05, 벽 friction -0.9, 중력 0.
- 매 프레임 속도 덮어쓰기는 튕김을 지운다. 거의 멈췄을 때만 순항한다.

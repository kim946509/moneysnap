---
id: WORK-048
status: review
depends_on: [WORK-047]
owner: unassigned
---

# 홈 유영 물리, 사진 hydrate, 그룹 스와이프, 카메라 추가

## Intent

홈 오브젝트는 천천히 떠다니며 부딪히면 살짝 튕기고, 사진은 실제로 보이며, 추가 화면은 카메라 구성, 그룹 캔버스는 총소비 위 스와이프로 본다.

## In scope

- 중력 없는 SpriteKit 유영, 속도 상한, 약한 드리프트
- 기록하기 버튼 약 20% 축소, 오브젝트 전체 축소
- refresh가 로컬 JPEG를 지우지 않게 hydrate 병합
- 홈 페이지: 나 + 내 그룹 순서, 내 그룹에서 순서 변경
- 금액 비공개 그룹 캔버스는 이미지만, 비공개 문구·금액 티켓 없음
- 추가 진입을 카메라형 화면으로 교체 (Figma `86:716` 방향)
- 그룹 today representative optional `imageRef`

## Out of scope

- Figma PNG baseline 재촬영
- 서버 group 순서 API
- Reduce Motion / visual Home rest 변경

## Acceptance criteria

- [x] 라이브 Home 물리는 중력이 없고 최고 속도가 제한된다
- [x] 기록하기 버튼은 기존 대비 약 80% 크기다
- [x] 금액 스케일 오브젝트는 더 작다
- [x] apply한 JPEG는 media GET 실패 refresh 뒤에도 남는다
- [x] 그룹이 있으면 총소비 위 인디케이터로 스와이프된다
- [x] 비공개 그룹 페이지는 금액 텍스트를 그리지 않는다
- [x] 추가 화면은 선택 리스트가 아니라 카메라 구성이다

## Test seam

- `TodaySnapViewModel` JPEG 보존
- `TodayCanvasPlacement` 축소 크기와 버튼
- `GroupCanvasOrder` 순서
- 서버 group today optional `imageRef`

## Verification

```text
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.contract.OpenApiContractTests" --tests "com.ansandy.moneysnap.media.MediaHttpIntegrationTests" --tests "com.ansandy.moneysnap.group.GroupHttpIntegrationTests" --no-daemon --console=plain
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
git diff --check
```

## Evidence

- 실행 명령: `cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.contract.OpenApiContractTests" --no-daemon --console=plain`
- 결과: BUILD SUCCESSFUL. `compileJava`/`compileTestJava` succeeded. Testcontainers media/group tests were not executed locally because Docker Desktop engine was not ready.
- `git diff --check`: clean
- `ios\scripts\validate-project.ps1`: PBX object IDs OK; visual baseline regression probe failed on reviewed manifest (pre-existing Windows visual contract, not files in this change)
- 리뷰: CI Ubuntu/macOS must run Testcontainers and iOS tests.

## Agent rules impact

- 영향 여부: no
- 근거: 기준 문서 경로, 제품·보안 불변, 승인 경계, 스택, 아키텍처 원칙, 검증 명령은 바뀌지 않았다. GET media는 이미 권한 검사 후 JPEG를 주는 계약이고, 그룹에 공유된 사진 읽기만 같은 경계를 넓혔다.
- 처리 결과: 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
- base: origin/main `f813023`
- risk: medium (media ACL, Home pager, capture sheet)
- findings와 처리 결과: 이 세션에 `code-review-graph` MCP가 없어 skip. 테스트와 원 명세로 리뷰했다.

## Decisions and risks

- 홈 물리는 기존 SpriteKit을 유지하고 중력 0, 감쇠, 속도 상한, 약한 드리프트로 유영한다.
- 사진 미표시 1차 원인: GET `/api/v1/media/{id}`가 JSON grant로 나가 JPEG가 아님. 응답을 `image/jpeg` 바이트로 바꾸고, refresh는 로컬 JPEG를 보존한다.
- 그룹 캔버스 사진은 공유된 LINKED object만 멤버가 GET할 수 있다.
- 그룹 페이지 순서는 UserDefaults. 서버 order API는 없다.
- 추가 시작 화면은 Figma `86:716` 방향의 카메라 구성이다. 토큰 만료로 PNG를 직접 대조하지는 못했다.
- 금액 비공개 그룹 캔버스는 금액 티켓/`비공개` 문구 없이 이미지만 그린다.

---
id: WORK-042
status: verify
depends_on: [WORK-025, WORK-010, WORK-021]
owner: unassigned
---

# Home 사진 표시, 빈 캔버스, 결합 입력, 저장 지연

## Intent

업로드한 사진을 Home/상세에 보이게 하고, 오늘 기록이 없어도 ₩0 캔버스를 유지하며, 카테고리와 금액을 한 시트에서 입력하고, 사진 업로드를 저장 전에 미리 시작해 저장 체감을 줄인다.

## In scope

- Today/detail/archive Snap 응답의 optional `imageRef`와 iOS GET `/api/v1/media/{id}` JPEG 표시
- 저장 직후 로컬 JPEG를 Home에 즉시 반영
- 오늘 기록 0건이어도 Home chrome + `오늘 총 소비 ₩0`
- 금액 비율로 Home 오브젝트 크기 조절(placeholder 포함)
- 라이브 기록 시트: 카테고리 위에 금액, 화면 약 80% detent
- 사진 attach 시 media publish prefetch, submit은 record 위주
- Figma staged `record-category`/`record-amount` visual 시나리오는 CI 기준으로 유지

## Out of scope

- TestFlight 재배포(코드 머지 후 별도 CD)
- 그룹 캔버스 사진 hydrate
- 보관함 리스트 사진 썸네일
- SpriteKit 물리 낙하 애니메이션
- R2/CD secret 회전

## Acceptance criteria

- [ ] 사진 없는 Today/detail/archive JSON은 기존 키만 유지하고 `imageRef`를 생략한다
- [ ] 연결된 사진이 있는 Snap은 Today/detail/archive에 `imageRef`를 포함하고 iOS가 JPEG를 표시한다
- [ ] 오늘 기록이 없으면 `오늘 기록이 없어요` 대신 Home 캔버스와 `₩0`을 보여 준다
- [ ] Home featured 오브젝트 크기는 artwork와 placeholder 모두 금액 비율을 따른다
- [ ] 라이브 기록은 카테고리와 금액을 한 시트에서 입력하고 시트 높이는 약 80%다
- [ ] 시각 시나리오 `record-category`/`record-amount`는 staged Figma 프레임을 유지한다
- [ ] 사진 기록은 attach 시점에 publish를 시작하고, record retry에서 publish를 다시 하지 않는다
- [ ] 서버 테스트와 Windows iOS 프로젝트 정적 검증을 통과한다

## Test seam

- `GET /api/v1/snaps/today`·`GET /api/v1/snaps/{id}` JSON 키와 optional `imageRef`
- `URLSessionSnapJournalClient` Today/detail decode
- `TodaySnapViewModel` empty today → content ₩0, local JPEG apply, media hydrate
- `TodayCanvasLayout` placeholder 금액 스케일
- `SnapCaptureModel` combined layout, prefetch publish
- `URLSessionMediaClient.fetchJPEG`

## Verification

```text
cd server; .\gradlew.bat test --no-daemon --console=plain
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.contract.OpenApiContractTests" --no-daemon --console=plain
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
git diff --check
```

## Evidence

- 실행 명령:
  - `cd server; .\gradlew.bat test --no-daemon --console=plain` → BUILD SUCCESSFUL
  - `cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.contract.OpenApiContractTests" --no-daemon --console=plain` (full suite에 포함) → BUILD SUCCESSFUL
  - `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1` → visual probe 실패. `capture-visual-baseline.sh`가 이 작업 트리에서 CRLF라 `xcodebuild \` 한 줄 계약 정규식이 0건. 이번 diff와 무관한 Windows checkout 이슈.
  - `git diff --check` → 통과
- 결과: 서버는 사진 있는 Snap의 Today/detail/archive/`imageRef`와 사진 없는 기존 exact key를 검증했다. iOS native test와 393x852 visual은 Windows에서 실행하지 못했다.
- 리뷰: code-review-graph MCP가 이 세션에 없어 skipped.

## Agent rules impact

- 영향 여부: no
- 근거: 제품 UX·API 응답 필드와 UI 가이드만 바뀌고, AGENTS.md의 스택·승인 경계·검증 명령은 그대로다.
- 처리 결과: 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
- base: n/a
- risk: medium (Home decode, media GET, capture layout)
- findings와 처리 결과: code-review-graph 도구가 연결되지 않아 영향 분석을 실행하지 못함. 서버 테스트와 계약 테스트로 대체 검증.

## Decisions and risks

- 라이브 입력은 80% 결합 시트. 100% 전체 화면은 Home 맥락을 가려서 쓰지 않는다.
- Figma `108:465`/`108:549` staged 프레임은 visual CI 원본으로 남기고, 라이브 UX는 사용자 결정이 우선한다.
- 빈 Home ₩0 캔버스는 Figma 9:2 populated 프레임과 다르며, 사용자 결정으로 UI_GUIDE를 갱신한다.
- Windows에서는 native iOS test·393x852 visual을 실행하지 못한다.

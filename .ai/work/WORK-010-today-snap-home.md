---
id: WORK-010
status: complete
depends_on: [WORK-006]
owner: codex
---

# Today Snap 홈 읽기 기반

## Intent

정책 결정이나 원격 배포 없이 오늘의 Snap·총 소비를 계산하고 Figma Home 기준으로 표시하는 첫 서버/iOS 기능 슬라이스를 완성한다.

## In scope

- 서버의 KRW 금액, MVP 카테고리, Today Snap 합계 도메인 규칙
- iOS `SnapJournalClient` seam과 결정론적 Home fixture
- Figma frame `9:2`의 393x852 Home 화면과 제공된 음식·카페 이미지 asset
- 서버 단위 테스트, iOS model/client 통합 테스트, macOS screenshot diff
- 다음 기능 단계를 위한 개발 계획

## Out of scope

- 인증 provider와 실제 owner 식별
- PostgreSQL schema, repository, REST endpoint와 Neon 연결
- Snap 저장·수정·삭제와 R2 업로드
- 그룹 정책과 공유
- development 서버 배포

## Acceptance criteria

- [x] `Money`는 양의 KRW 정수만 허용하고 MVP 카테고리는 기준 문서의 8개 값으로 고정된다.
- [x] Today Snap 합계는 당일 entry 전체에서 계산되며 overflow 없이 표현된다.
- [x] iOS Home은 fixture client를 통해 화면 상태를 적재하고 Figma 기준 날짜, 카드, 총액, 최근 소비를 표시한다.
- [x] Home의 상태는 loading, content, failure를 구분한다.
- [x] Home root가 기존 tab별 navigation 상태 격리 계약을 깨지 않는다.
- [x] 393x852 simulator evidence가 생성되고 Figma reference와 정량·육안 비교된다.
- [x] 서버·iOS 검증이 모두 통과하고 WORK-010 범위의 커밋만 포함하며, `main` 병합 시 하나의 기능 커밋으로 squash한다.

## Test seam

- 서버 seam: 순수 `snap` 도메인 타입과 일별 요약 객체를 JUnit 단위 테스트로 먼저 실패시킨다.
- 공용 의미 seam: category code와 KRW integer 의미를 서버/iOS 양쪽의 동일한 fixture 값으로 검증한다.
- iOS seam: `SnapJournalClient`를 in-memory adapter로 교체해 `TodaySnapViewModel`의 loading/content/failure 전이를 검증한다.
- 시각 seam: Figma `9:2` reference와 iPhone 16·iOS 18.5의 393x852 screenshot을 비교한다.

## Verification

```text
cd server; .\gradlew.bat test --no-daemon --console=plain
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
bash ios/scripts/test.sh
bash ios/scripts/capture-visual-baseline.sh
git diff --check
```

## Evidence

- 서버 RED: 도메인 테스트를 먼저 추가했을 때 `KrwAmount`, `SnapCategory`, `TodaySnapEntry`, `TodaySnapSummary` 부재로 compile 실패를 확인했다.
- 서버 GREEN: `cd server; .\gradlew.bat test --no-daemon --console=plain` → `BUILD SUCCESSFUL` (최종 로컬 재실행 11초).
- iOS RED/GREEN: 금액 불변식·overflow·fixture load/failure·금액 비례 layout 테스트를 먼저 추가하고 GitHub macOS native test로 통과시켰다. 초기 `@testable import` 실패는 app Debug `ENABLE_TESTABILITY=YES`로 수정했다.
- Windows 계약: `validate-project.ps1`, `validate-visual-baseline.ps1`, `validate-cicd.ps1` 모두 `OK`; `git diff --check` 오류 없음.
- 서버 원격 검증: GitHub Actions run `31297345734`에서 test, production JAR, immutable Docker image가 성공했고 PR 조건의 deploy job은 의도대로 skipped 됐다.
- iOS 원격 검증: GitHub Actions run `31297345743`에서 Xcode 16.4·iPhone 16·iOS 18.5 native test와 Figma capture가 성공했다.
- 시각 증거: artifact `9033439126`, 393x852 app/reference/overlay/diff를 육안 검수했다. report는 `passed: true`, MAE `0.045383333501204021 <= 0.05`, mismatched pixel ratio `0.41412512394127277 <= 0.43`이다.
- 기능 커밋: `67ed062`, `178755b`, `19fb8c0`, `d471236`, `55af723`, `a155d14`. 원격 macOS 시각 피드백을 반영한 WORK-010 전용 연속 커밋이며 unrelated 작업은 제외했다. `main`에는 squash merge한다.
- 독립 리뷰: 명세·보안 축과 코드·테스트 축 모두 코드 blocker 없음. 문서 상태, 커밋 의미, 잘못된 `WORK-008` 의존성 지적은 이 종료 갱신에서 해결했다.

## Agent rules impact

- 영향 여부: yes
- 근거: 첫 사용자 기능 슬라이스 완료, 실제 시각 회귀 임계값, 다음 사용자 기능 게이트가 프로젝트 현재 단계에 영향을 준다.
- 처리 결과: 기준 문서인 `docs/DEVELOPMENT_PLAN.md`를 먼저 완료 상태로 갱신하고 `AGENTS.md` 현재 단계 요약을 동기화했다. 실시간 세부 증거는 이 작업 항목에만 유지한다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: 유효한 기존 graph를 기준으로 source 변경 묶음마다 incremental update; full rebuild 없음
- review base: `24f0540`; 최종 incremental base: `55af723`
- final risk: low (`0.35`)
- findings와 처리 결과: 초기 iOS 금액 불변식/overflow, 고정 geometry, 토큰 중복, report-only visual 검증 공백을 TDD로 수정했다. 최종 graph의 `TodaySnapContent` 정적 test gap은 Windows layout 계약과 macOS 전체 app screenshot threshold로 보완했고 독립 리뷰에서 코드 blocker가 없음을 확인했다.
- graph 범위: 작업 전부터 존재한 Ponytail 하네스 문서 변경이 자동 changed-file 목록에 잡혀, 최종 `detect_changes`는 WORK-010의 iOS source·검증 파일을 명시해 실행했다.

## Decisions and risks

- 첫 단계는 인증·사진 quota·그룹 정책을 추론하지 않도록 read-only fixture와 순수 도메인 규칙에 한정한다.
- Figma 총액은 화면에 노출된 세 카드 합계보다 크므로 fixture 전체 ledger에는 화면 밖 entry를 포함하고 UI는 지정된 featured/recent subset만 렌더링한다.
- custom font와 pixel threshold는 macOS 증거를 보고 Home parity를 해치지 않는 최소 범위에서 결정한다.
- `WORK-008`은 Ponytail 하네스 개선 작업으로 이 기능의 실행 선행조건이 아니다. 잘못 선언된 의존성을 제거했고 해당 사용자 변경은 이 작업의 커밋에 포함하지 않았다.
- macOS-only screenshot feedback 때문에 기능 브랜치에는 후보·보정 커밋이 필요했다. 사용자 요청의 기능 단위 이력을 유지하면서 `main` 결과는 squash merge 한 커밋으로 만든다.

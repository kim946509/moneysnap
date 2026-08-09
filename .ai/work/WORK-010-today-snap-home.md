---
id: WORK-010
status: active
depends_on: [WORK-006, WORK-008]
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

- [ ] `Money`는 양의 KRW 정수만 허용하고 MVP 카테고리는 기준 문서의 8개 값으로 고정된다.
- [ ] Today Snap 합계는 당일 entry 전체에서 계산되며 overflow 없이 표현된다.
- [ ] iOS Home은 fixture client를 통해 화면 상태를 적재하고 Figma 기준 날짜, 카드, 총액, 최근 소비를 표시한다.
- [ ] Home의 상태는 loading, content, failure를 구분한다.
- [ ] Home root가 기존 tab별 navigation 상태 격리 계약을 깨지 않는다.
- [ ] 393x852 simulator evidence가 생성되고 Figma reference와 정량·육안 비교된다.
- [ ] 서버·iOS 검증이 모두 통과한 뒤 하나의 기능 커밋으로 닫힌다.

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

- 실행 명령: 진행 중
- 결과: 진행 중
- 리뷰: 진행 중

## Agent rules impact

- 영향 여부: pending
- 근거: 기능 단계와 실제 검증 명령이 확정되면 `AGENTS.md`의 현재 단계 요약 영향 여부를 검토한다.
- 처리 결과: pending

## Code Review Graph

- 코드 변경 여부: yes
- graph action: pending incremental update
- base: `24f0540`
- risk: pending
- findings와 처리 결과: pending

## Decisions and risks

- 첫 단계는 인증·사진 quota·그룹 정책을 추론하지 않도록 read-only fixture와 순수 도메인 규칙에 한정한다.
- Figma 총액은 화면에 노출된 세 카드 합계보다 크므로 fixture 전체 ledger에는 화면 밖 entry를 포함하고 UI는 지정된 featured/recent subset만 렌더링한다.
- custom font와 pixel threshold는 macOS 증거를 보고 Home parity를 해치지 않는 최소 범위에서 결정한다.

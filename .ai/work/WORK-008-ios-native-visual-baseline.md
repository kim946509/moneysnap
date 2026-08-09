---
id: WORK-008
status: verify
depends_on: [WORK-007]
owner: codex
---

# iOS native·시각 검증 기준선 활성화

## Intent

GitHub macOS runner에서 Money Snap을 고정된 Xcode·Simulator 조합으로 native 검증하고, Figma 홈 frame과 비교 가능한 393x852 시각 증거를 매 변경마다 생성한다.

## In scope

- 첫 원격 iOS CI의 Swift 6 concurrency compile failure 수정
- 최종 repository Bundle ID 고정
- Figma 홈 `9:2`의 393x852 reference와 checksum manifest 보존
- Xcode 16.4, iPhone 16, iOS 18.5 Simulator 기준선 고정
- 실제 앱 screenshot, overlay, pixel diff와 JSON report 생성
- GitHub Actions visual evidence artifact와 기준 문서·`AGENTS.md` 동기화

## Out of scope

- 홈 화면 기능 구현과 Figma parity threshold 통과
- Noto Sans KR·Inter를 SF Pro로 대체할지 결정
- Apple Developer App ID, App Store Connect app record, signing certificate 생성
- Xcode Cloud 첫 workflow와 TestFlight upload
- Windows self-hosted runner 설치와 Neon secret 업로드

## Acceptance criteria

- [ ] `AppTab`은 Swift 6 strict concurrency에서 compile 가능한 값 타입이다.
- [ ] Bundle ID `com.ansandy.moneysnap`을 repository의 최종 식별자로 기록한다.
- [ ] Figma `9:2` reference는 393x852이며 manifest SHA-256과 일치한다.
- [ ] iOS test와 screenshot은 Xcode 16.4, iPhone 16, iOS 18.5를 사용한다.
- [ ] macOS CI는 393x852 app screenshot, Figma reference, overlay, diff와 report를 artifact로 남긴다.
- [ ] 홈 기능 전에는 visual diff를 report-only로 운용하고 parity 성공으로 오인하지 않는다.
- [ ] Windows 정적 계약, shell syntax, 서버 회귀 검증과 실제 GitHub Actions를 통과한다.

## Test seam

- 먼저 `ios/scripts/validate-visual-baseline.ps1`이 manifest, reference checksum, Swift concurrency, 고정 Simulator와 workflow artifact 계약 부재로 실패하게 한다.
- 구현 뒤 같은 validator와 기존 iOS project/CI/CD validator를 통과시킨다.
- 최종 native build·test와 screenshot 생성은 GitHub `macos-15` runner에서 검증한다.

## Verification

```text
powershell -NoProfile -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1
bash -n ios/scripts/resolve-simulator.sh
bash -n ios/scripts/test.sh
bash -n ios/scripts/capture-visual-baseline.sh
git diff --check
GitHub PR checks
```

## Evidence

- RED:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1` → `Visual baseline manifest is missing.`로 실패
  - GitHub iOS CI run `31288321354` → Swift 6 strict concurrency가 non-Sendable `AppTab.initial`을 거부해 exit 65
- GREEN:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1` → `MoneySnap iOS visual baseline contract: OK`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1` → `MoneySnap iOS project static validation: OK`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1` → `Money Snap CI/CD static contract: OK`
  - Git Bash `bash -n`으로 resolver/test/capture script syntax 통과
- 외부 상태:
  - Figma design context와 export에서 홈 `9:2`가 393x852임을 확인하고 SHA-256 `4e821694...491d75`로 고정
  - GitHub run inventory에서 Xcode 16.4, iPhone 16, iOS 18.5를 확인
  - GitHub iOS run `31289000087`에서 native test, app capture, Swift diff와 artifact upload가 성공
  - 내려받은 artifact는 app/reference/overlay/diff가 모두 393x852이고 reference SHA-256이 manifest와 일치
  - artifact 육안 검토에서 overlay/diff의 CoreGraphics 수직 좌표가 뒤집힌 문제를 발견해 불필요한 flip transform을 제거하고 재실행 대기
- 리뷰:
  - Code Review Graph는 Swift diff helper를 test gap으로 표시했다. macOS CI가 helper를 실제 reference/Simulator screenshot으로 실행하는 integration seam이며 별도 unit target은 추가하지 않는다.

## Agent rules impact

- 영향 여부: yes
- 근거: native CI의 실제 상태, 고정 Simulator, Bundle ID와 시각 완료 기준이 바뀐다.
- 처리 결과: `docs/ADR.md`, `docs/CI_CD.md`, `ios/README.md`, `AGENTS.md` 동기화

## Code Review Graph

- 코드 변경 여부: yes
- graph action: `full_rebuild=false`, base `a7ba1d1` 증분 update
- base: `a7ba1d1`
- risk: low `0.40`; 89 nodes, 381 edges, 32 files
- findings와 처리 결과: `AppTab`·visual diff helper test gap을 확인했다. AppTab은 기존 Swift Testing, helper는 실제 macOS artifact integration run으로 검증하며 남은 graph finding은 없다.

## Decisions and risks

- 결정: Figma viewport와 정확히 같은 points 크기를 제공하는 iPhone 16을 사용한다.
- 결정: runner에서 실제 확인된 안정 조합인 Xcode 16.4·iOS 18.5를 기준선으로 고정한다.
- 위험: GitHub runner image에서 Xcode 16.4 또는 iOS 18.5가 제거되면 의도적으로 CI가 실패하며 ADR 변경이 필요하다.
- 위험: 현재 앱은 placeholder이므로 visual diff는 큰 차이를 보고한다. 홈 기능 작업에서 승인 threshold를 별도 AC로 활성화한다.

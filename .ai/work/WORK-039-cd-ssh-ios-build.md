---
id: WORK-039
status: active
depends_on: [WORK-036, WORK-037, WORK-038]
owner: grok
---

# CD SSH 정규화와 iOS CI 빌드 복구

## Intent

main CD의 SSH BOM/키 로드 실패와 iOS native CI 컴파일 실패를 고쳐, 아이폰 실물 설치를 제외한 development 배포와 Simulator CI를 다시 통과시킨다.

## In scope

- deploy job이 host/user/port/key의 UTF-8 BOM과 CR을 제거하고 키가 loadable인지 검사
- `SERVER_SSH_PORT=2222`, `SERVER_SSH_USER=root`, `SERVER_HOST`를 BOM 없이 재등록
- iOS `AppShellView` 타입 추론과 `SnapJournalClient` `Sendable` 컴파일 수정
- Cloudflare 플러그인/Wrangler로 R2 S3 token 발급 시도

## Out of scope

- 아이폰 실기기 서명·TestFlight
- 대화에 .p8/R2 secret 수신
- PR CI에 deployment secret 주입
- Cloudflare DNS/NPM 변경

## Acceptance criteria

- [x] `scripts/validate-cicd.ps1`가 BOM strip과 ssh-keygen 계약을 통과한다.
- [x] iOS `AppShellView`/`SnapJournalClient` 컴파일 오류를 수정했다. 전체 `validate-project.ps1`은 기존 WORK-035 visual probe에서 실패한다.
- [x] `server-development`의 SSH port/user/host를 `--body`로 재등록했다. TCP 2222는 열려 있다.
- [ ] 코드 변경은 PR로 `main`에 들어가고 Server·iOS CI는 PR에서 통과한다. `GroupDetailModelTests`의 tuple/`UUID.owned` 컴파일 오류도 수정했다.

## Test seam

- CI/CD static contract
- iOS compile-time Sendable/`SnapCaptureModel` 초기화 타입

## Verification

```text
powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
```

## Evidence

- 실행 명령: `powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1`; `Test-NetConnection 61.109.115.47 -Port 2222`; public `/` smoke
- 결과: `Money Snap CI/CD static contract: OK`; port 2222 `TcpTestSucceeded=True`; `{"service":"moneysnap-api","status":"UP"}`. Wrangler OAuth는 R2 bucket list 200, permission group/token create 403, `/r2/tokens` 404.
- 리뷰:

## Agent rules impact

- 영향 여부: no
- 근거: SSH CD, R2 secret 위치, PR CI 비주입, Mac-only 실기기 규칙은 그대로다.
- 처리 결과: 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped if graph tools unavailable
- findings와 처리 결과:

## Decisions and risks

- Windows `gh secret set`가 BOM을 붙일 수 있으므로 `--body`로 재등록하고 workflow에서도 strip한다.
- Wrangler OAuth는 R2 object API는 가능해도 User API Tokens Write가 없으면 S3 Access Key를 만들 수 없다.

---
id: WORK-041
status: review
depends_on: [WORK-037]
owner: grok
---

# GitHub Actions iOS TestFlight CD

## Intent

Windows에서 Mac 없이 Money Snap iOS 앱을 App Store Connect / TestFlight에 올리기 위해, public 레포의 PR CI와 분리된 GitHub-hosted macOS archive lane을 추가한다.

## In scope

- `ios-testflight` environment와 `main` 성공 iOS CI 이후 archive/upload workflow
- App Store Connect API key 기반 automatic signing
- CI/CD 정적 계약과 기준 문서·`AGENTS.md` 동기화

## Out of scope

- 대화에 `.p8`/인증서 수신
- PR/iOS test job에 배포 secret 주입
- Xcode Cloud 첫 workflow 생성
- 서버 CD 변경
- 레포 분리

## Acceptance criteria

- [x] `.github/workflows/ios-testflight.yml`은 `pull_request`에서 실행되지 않는다.
- [x] iOS CI workflow는 App Store Connect/배포 secret을 참조하지 않는다.
- [x] deploy job은 `ios-testflight` environment와 필수 secret 존재 검사를 한다.
- [x] `scripts/validate-cicd.ps1`이 위 계약을 검사한다.

## Test seam

- repository CI/CD static contract

## Verification

```text
powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1
```

## Evidence

- 실행 명령: `powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1`
- 결과: `Money Snap CI/CD static contract: OK`
- GitHub environment: `ios-testflight` created with custom branch policy `main` only. Secrets are not registered yet.
- 리뷰: 첫 실제 업로드는 사용자가 App Store Connect API key 4개를 `ios-testflight`에 넣은 뒤 `main`에서 `workflow_dispatch`해야 한다. 값은 대화에 붙이지 않는다.

## Agent rules impact

- 영향 여부: yes
- 근거: iOS TestFlight CD가 Xcode Cloud에서 GitHub-hosted macOS + `ios-testflight` environment로 바뀐다.
- 처리 결과: `docs/CI_CD.md`, `docs/ADR.md`, `infra/apple/README.md`, `AGENTS.md`를 같은 작업에서 동기화한다.

## Code Review Graph

- 코드 변경 여부: no application source
- graph action: skipped, workflow/docs only

## Decisions and risks

- 첫 실제 업로드는 사용자가 App Store Connect API key를 `ios-testflight` secret에 넣은 뒤에만 성공한다.
- automatic signing은 API key가 Certificate 생성 권한을 가져야 한다.

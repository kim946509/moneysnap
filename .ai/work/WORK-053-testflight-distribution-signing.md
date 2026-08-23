---
id: WORK-053
status: active
depends_on: [WORK-052]
owner: unassigned
---

# TestFlight archive는 Apple Distribution만 쓴다

## Intent

GitHub-hosted TestFlight archive가 iOS Development 인증서를 새로 만들지 않고, 이미 있는 Apple Distribution cloud signing만 사용한다.

## In scope

- `ios-testflight.yml` archive `CODE_SIGN_IDENTITY`
- export options `signingCertificate`
- CI/CD 정적 계약

## Out of scope

- Apple 인증서 폐기
- `.p12`를 저장소에 넣기
- PR iOS CI 서명

## Acceptance criteria

- [x] archive는 로컬 Development 인증서 없이 만든다
- [x] export options가 Distribution 인증서를 명시한다
- [x] `validate-cicd.ps1`이 위 계약을 검사한다

## Test seam

- `scripts/validate-cicd.ps1`

## Verification

```text
powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1
git diff --check
```

## Evidence

- 실행 명령: `powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1`
- 결과: Money Snap CI/CD static contract: OK
- `git diff --check`: clean
- 리뷰: TestFlight archive 재실행으로 확인

## Agent rules impact

- 영향 여부: no
- 근거: TestFlight는 계속 App Store Connect Team API key와 cloud-managed Distribution이다. 개발 인증서를 만들지 않게 고정한 것이다.
- 처리 결과: 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
- base: origin/main
- risk: low
- findings와 처리 결과: workflow 계약만 바뀐다. MCP 없음.

## Decisions and risks

- 실패 1: Automatic archive가 GitHub runner마다 iOS Development 인증서를 만들려다 한도에 걸린다.
- 실패 2: Automatic + `CODE_SIGN_IDENTITY=Apple Distribution`은 Xcode가 충돌로 거절한다.
- archive는 서명하지 않고, export만 Apple Distribution cloud signing을 쓴다.

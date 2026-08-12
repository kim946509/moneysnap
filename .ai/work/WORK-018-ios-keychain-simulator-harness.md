---
id: WORK-018
status: done
depends_on: [WORK-008]
owner: codex
---

# iOS Simulator Keychain test 서명 하네스 보정

## Intent

Apple credential이나 배포 서명 없이 GitHub-hosted iOS Simulator가 app-hosted Keychain 통합 테스트를 Xcode 기본 ad-hoc 서명으로 실행하게 한다.

## In scope

- `ios/scripts/test.sh`의 native test invocation에서 `CODE_SIGNING_ALLOWED=NO` 제거
- CI 계약 검증이 unsigned Keychain regression을 거부하도록 보정
- GitHub Actions job 이름과 CI·아키텍처 문서의 Simulator ad-hoc signing 계약 동기화
- remote macOS native test·Home/My visual evidence 재실행

## Out of scope

- Apple Developer team, certificate, provisioning profile, App ID 또는 secret 추가
- physical device, archive, TestFlight 서명
- `capture-visual-baseline.sh`의 순수 screenshot build 서명 정책 변경
- Keychain production adapter나 테스트 삭제·mock 대체

## Acceptance criteria

- [x] Simulator app·test host가 Xcode `Sign to Run Locally` ad-hoc 서명으로 실행된다.
- [x] Keychain save/load/clear 3건이 `errSecMissingEntitlement (-34018)` 없이 통과한다.
- [x] native suite 전체와 Home/My 393x852 visual threshold가 통과한다.
- [x] repository에 `DEVELOPMENT_TEAM`, Apple credential, certificate·profile을 추가하지 않는다.
- [x] CI 정적 계약이 native test에 `CODE_SIGNING_ALLOWED=NO`가 재도입되는 변경을 거부한다.

## Test seam

- red seam: remote run `31544943204`의 `KeychainSessionStoreTests` 3건이 `KeychainSessionStoreError(status: -34018)`로 실패한다.
- static seam: CI validator가 native test script의 result bundle·workflow 연결을 유지하고 unsigned override를 금지한다.
- held-out seam: GitHub-hosted `macos-15`, Xcode 16.4, iPhone 16/iOS 18.5에서 CodeSign·Keychain·visual 결과를 확인한다.

## Verification

```text
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1
bash -n ios/scripts/test.sh
GitHub Actions iOS CI workflow_dispatch on exact revision
git diff --check
```

## Evidence

- 실행 명령:
  - remote iOS CI run `31544943204`
  - `powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1` (guard 구현 전·후)
  - `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1`
  - `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1`
  - `bash -n ios/scripts/test.sh`
  - `git diff --check`
  - GitHub Actions iOS CI workflow_dispatch run `31650035417` on `73787261ebe9ed995bf631999799b8ee912efdc8`
- 결과:
  - native test 9건 실패 중 Keychain 3건의 공통 error가 `-34018`; app-hosted test를 `CODE_SIGNING_ALLOWED=NO`로 실행한 기존 하네스와 일치
  - unsigned native-test override 금지 guard가 구현 직후 기존 script에서 의도대로 실패하고 override 제거 뒤 통과
  - workflow에 `CODE_SIGNING_ALLOWED: NO`를 임시 주입했을 때 validator가 실패했고, 임시 회귀 제거 뒤 다시 통과해 shell `=`와 YAML `:` 우회를 모두 차단함
  - project·visual·CI/CD 정적 계약, shell syntax와 whitespace 검증 통과
  - `/usr/bin/codesign --force --sign - --timestamp=none --generate-entitlement-der`가 app·test bundle에 적용되고 native 59 tests, 실패 0으로 성공
  - `KeychainSessionStoreTests`의 save/load, clear, device-only·when-unlocked 3건이 모두 통과
  - Home MAE `0.0453833335`/mismatch `0.4141251239`, My MAE `0.0301637864`/mismatch `0.2252027858`로 상한 `0.05`/`0.43` 통과
  - visual artifact `ios-visual-evidence-73787261ebe9ed995bf631999799b8ee912efdc8`의 app/reference/overlay/diff/report와 393x852 환경을 직접 검수함
- 리뷰: 2026-08-13 사용자가 `WORK-018`부터 `WORK-022`까지 모두 명시적으로 승인함

## Agent rules impact

- 영향 여부: no
- 근거: 기존 macOS native iOS 검증 명령과 Apple activation 승인 경계는 유지하고 Simulator test host의 실행 방식만 정정한다.
- 처리 결과: 2026-08-13 승인 후 하네스를 보정했으며, 실제 검증 명령과 Apple activation 경계가 바뀌지 않아 현재 `AGENTS.md` 본문 갱신 불필요

## Code Review Graph

- 코드 변경 여부: no
- graph action: skipped
- base: `593e527`
- risk: medium (CI held-out validation boundary)
- findings와 처리 결과: shell·workflow·문서 하네스 작업으로 graph parser 대상 production 소스 변경 없음; spec/standards 재리뷰에서 원격 증거 외 finding 0건이었고 run `31650035417`로 마지막 finding 해소

## Decisions and risks

- 2026-08-13 사용자 명시 승인 범위 안에서 `test.sh`, validator와 workflow 하네스를 변경했다.
- Simulator ad-hoc signing은 device distribution signing이 아니며 Apple 계정·유료 자원을 사용하지 않는다.
- visual capture는 Keychain을 사용하지 않으므로 기존 unsigned build를 유지한다.

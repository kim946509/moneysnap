---
id: WORK-007
status: verify
depends_on: [WORK-006]
owner: codex
---

# 서버·iOS CI/CD 자동화

## Intent

Money Snap 변경이 자동 검증되고, 승인된 `main` revision만 무료 Windows origin과 이후 TestFlight lane으로 승격될 수 있는 반복 가능한 배포 경로를 만든다.

## In scope

- GitHub Actions의 Spring Boot PR/push CI와 immutable JAR artifact
- `main` push에서 `server-development` environment와 전용 self-hosted Windows runner만 사용하는 서버 CD
- Windows origin의 release 보관, secret file 격리, health smoke와 자동 rollback script
- GitHub Actions dependency update 계약
- Xcode Cloud가 Swift native test·archive·TestFlight를 맡는 repository 준비 계약
- workflow와 script의 결정론적 Windows 정적 검증
- 기준 문서와 `AGENTS.md` 동기화

## Out of scope

- source 변경의 commit·push·PR 생성
- GitHub Actions runner 등록 token, environment secret 실제 값 저장
- Apple App ID/App Store Connect app record 생성, signing과 첫 TestFlight upload
- Cloudflare named Tunnel/DNS route 생성
- production 공개 배포와 유료 Cloudflare Containers

## Acceptance criteria

- [x] server workflow는 PR에서 Java 21 test와 bootJar를 실행하고 JAR artifact를 만든다.
- [x] main push deployment만 `server-development` environment와 `[self-hosted, Windows, X64, moneysnap-dev]` runner를 사용한다.
- [x] deployment는 GitHub environment secret을 log·command line에 넣지 않고 origin의 제한된 secret files로 전달한다.
- [x] deployment는 새 JAR health가 `UP`이고 상세 component가 없을 때만 성공하며 실패 시 이전 release로 rollback한다.
- [x] 중복 main deployment는 concurrency로 직렬화되고 job permissions는 contents read만 허용한다.
- [x] iOS native CI/CD는 Xcode Cloud를 사용하며 pull request test와 main archive/TestFlight 조건, macOS activation gate가 문서화된다.
- [x] workflow/action update와 repository secret·environment·runner 계약이 문서화된다.
- [x] CI/CD 정적 검증, 서버 test·bootJar, iOS project 정적 검증이 통과한다.
- [x] Code Review Graph update와 독립 리뷰 finding 처리 결과가 기록된다.
- [x] 기준 문서와 `AGENTS.md`가 실제 CI/CD 경로·명령·미활성 gate와 일치한다.

## Test seam

- server CI/CD: `.github/workflows/server-ci-cd.yml`의 trigger, permission, artifact와 deployment job 계약
- Windows deployment: `server/scripts/deploy.ps1`의 secret 경계, health gate와 rollback 계약
- iOS CI/CD: `ios/ci_scripts`와 `infra/apple/README.md`의 Xcode Cloud hook·activation 계약

workflow는 GitHub/Apple이 호출하는 public automation interface다. secret 값이나 private helper가 아니라 trigger, runner, environment, artifact, smoke/rollback이라는 외부 동작을 검증한다.

## Verification

```text
powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1
cd server; .\gradlew.bat test --no-daemon --console=plain
cd server; .\gradlew.bat bootJar --no-daemon --console=plain
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
git diff --check
```

## Evidence

- RED:
  - `powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1` → server workflow가 없어 실패
  - `powershell -ExecutionPolicy Bypass -File server\scripts\test-deployment-support.ps1` → `MoneySnap.Deployment.psm1`이 없어 실패
  - orchestration test 추가 뒤 같은 명령 → `Assert-MoneySnapHealthResponse`가 없어 실패
- GREEN:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1` → `Money Snap CI/CD static contract: OK`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File server\scripts\test-deployment-support.ps1` → checksum 변조 거부, ACL, JAR·runner·secret 복원, health 판정과 성공/rollback ordering 통과
  - `cd server; .\gradlew.bat test bootJar --no-daemon --console=plain` → `BUILD SUCCESSFUL in 10s`, canonical `build/libs/moneysnap-server.jar`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1` → `MoneySnap iOS project static validation: OK`
  - Git Bash `bash -n ios/scripts/test.sh`, `bash -n ios/ci_scripts/ci_post_clone.sh` → 통과
  - PyYAML parse of server/iOS workflow와 Dependabot → 통과
  - PowerShell parser of deployment/module/test/bootstrap/validator → 통과
- 외부 상태:
  - GitHub `server-development` environment 생성 확인, protection rule 없음, environment secret 목록 0개
  - repository self-hosted runner 개수 0개
  - CI/CD source는 작업별 local commit으로 고정하고 있으며 remote push 전이므로 GitHub workflow run과 Xcode Cloud/TestFlight run은 미실행
  - local Neon development credential의 GitHub secret upload는 별도 명시 승인이 없어 실행하지 않음
- 리뷰:
  - Standards·Spec 독립 리뷰에서 ACL 적용 순서, deployment 동작 테스트, `contracts/**` trigger, Java 경로, health/rollback orchestration과 validator pin/secret 검증 공백을 발견
  - ACL-before-write, Windows behavior job, 절대 Java 경로, 정확한 40자리 action SHA·6개 secret 검사, 테스트된 health/rollback orchestration으로 모두 처리
  - 두 리뷰의 최종 재검토 결과 남은 finding 0개

## Agent rules impact

- 영향 여부: yes
- 근거: CI/CD 구조, 배포 승인 경계, 실제 검증 명령과 다음 프로젝트 gate가 바뀐다.
- 처리 결과: `docs/ADR.md`, `docs/ARCHITECTURE.md`, `docs/CI_CD.md`, infra/server/iOS README와 `AGENTS.md`의 단계·불변 규칙·명령·미활성 gate를 동기화했다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: 기존 graph를 `full_rebuild=false` incremental update하고 수정 뒤 다시 incremental update
- base: `HEAD`
- risk: graph 결과 `low (0.00)`; PowerShell/YAML 함수·flow edge를 인식하지 못해 독립 리뷰와 동작 테스트를 주 증거로 사용
- final graph: 73 nodes, 240 edges, 27 files; 변경 7개 파일에 graph finding 0개
- findings와 처리 결과: 독립 Standards/Spec finding을 전부 수정하고 최종 재검토에서 0개 확인

## Decisions and risks

- 결정: Spring Boot CI/CD는 GitHub Actions, iOS native CI/CD는 accepted ADR대로 Xcode Cloud를 사용한다.
- 결정: 무료 서버 CD는 공개 GitHub-hosted runner가 origin에 원격 접속하지 않고 전용 self-hosted Windows runner가 local release를 교체한다.
- 위험: repository가 private이므로 GitHub-hosted macOS Actions는 quota를 소비한다. iOS native job은 Xcode Cloud 포함 quota를 우선한다.
- 위험: source local commit 이후에도 remote push되지 않았고 runner·GitHub environment secret·Apple App record가 없으므로 실제 원격 run과 TestFlight 활성화는 별도 external gate다. `server-development` environment container만 생성되어 있고 secret은 0개다.

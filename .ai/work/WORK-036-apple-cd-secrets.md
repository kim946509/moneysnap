---
id: WORK-036
status: verify
depends_on: [WORK-014, WORK-007]
owner: grok
---

# GitHub development CD Apple runtime secret

## Intent

Sign in with Apple runtime 값을 Ubuntu host `.env`에 수동으로 두지 않고, `server-development` environment secret과 `main` development CD만으로 `/opt/moneysnap/.env`에 쓰이게 한다.

## In scope

- `deploy-development` job이 Apple runtime secret 6개를 runtime env file에 기록
- PEM 개행을 env 한 줄의 literal `\n`으로 정규화
- 필수 secret이 비면 deploy를 실패시켜 빈 값으로 host `.env`를 덮어쓰지 않음
- PR/test/iOS job에는 Apple secret을 주입하지 않음
- CI/CD 정적 검증과 기준 문서·`AGENTS.md` 동기화
- 대화에 없는 `APPLE_REFRESH_TOKEN_ENCRYPTION_KEY`를 environment secret으로 등록

## Out of scope

- `.p8`, Team ID, Key ID, 2FA를 대화·commit·로그에 받기
- live R2, production environment, Apple App ID/Xcode capability/TestFlight
- PR CI에 deployment secret 주입
- 현재 detached worktree를 `main`에 merge·deploy

## Acceptance criteria

- [x] `server-ci-cd.yml`의 `deploy-development`만 `secrets.APPLE_*` 6개를 참조한다.
- [x] build/PR/iOS job은 Apple secret을 참조하지 않는다.
- [x] CD는 `.p8`의 실제 개행을 `APPLE_PRIVATE_KEY_P8` 한 줄 literal `\n`으로 쓴다.
- [x] Apple runtime secret이 비어 있으면 deploy job이 실패한다.
- [x] `scripts/validate-cicd.ps1`이 위 계약을 검사한다.
- [x] `APPLE_REFRESH_TOKEN_ENCRYPTION_KEY`는 `server-development`에 존재한다.
- [x] `APPLE_PRIVATE_KEY_P8`은 로컬 `gh secret set`으로만 등록하며 이 대화에 값이 없다.

## Test seam

- `.github/workflows/server-ci-cd.yml`의 environment secret 참조, deploy-only 경계, 빈 값 거부
- `scripts/validate-cicd.ps1`의 Apple secret allowlist와 build-job 격리

## Verification

```text
powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1
gh secret list --env server-development
```

## Evidence

- 실행 명령: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1`
- 결과: `Money Snap CI/CD static contract: OK`
- `gh auth status`: `kim946509`, scopes `gist`, `read:org`, `repo`, `workflow`
- `gh secret list --env server-development`: Neon/SSH 11개와 Apple 6개 이름이 존재. 값은 조회하지 않음.
- 리뷰: 애플리케이션 소스 변경 없음. Code Review Graph skipped.

## Agent rules impact

- 영향 여부: yes
- 근거: GitHub-hosted CI에 Apple secret을 넣지 않는다는 문장이 deploy-development와 충돌한다. PR/test와 development CD를 구분해야 한다.
- 처리 결과: `AGENTS.md`의 secret 주입 문장과 `server-development` secret 요약을 갱신한다.

## Code Review Graph

- 코드 변경 여부: no
- graph action: skipped
- base:
- risk:
- findings와 처리 결과: workflow·문서·검증 스크립트만 변경하므로 애플리케이션 소스 그래프를 갱신하지 않는다.

## Decisions and risks

- Apple 키 값은 채팅에 받지 않는다. `gh`는 `repo`/`workflow` scope로 environment secret 이름 조회와 쓰기가 가능하다.
- `APPLE_PRIVATE_KEY_P8`이 등록되기 전에 이 workflow가 `main`에 배포되면 CD는 의도적으로 실패한다.

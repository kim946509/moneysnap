---
id: WORK-038
status: active
depends_on: [WORK-025]
owner: grok
---

# private R2 ObjectStore Adapter

## Intent

개인 Snap 사진을 프로세스 메모리가 아니라 이미 만든 private R2 bucket `moneysnap-media-dev`에 저장한다.

## In scope

- AWS SDK v2 S3-compatible `ObjectStore` Adapter
- `R2_ENABLED=false`이면 기존 MemoryObjectStore 유지 (테스트·로컬)
- `R2_ENABLED=true`이면 endpoint·bucket·access key가 모두 있어야 기동
- development CD가 `server-development` R2 secret을 `/opt/moneysnap/.env`에만 씀
- PR/test job에는 R2 secret을 넣지 않음

## Out of scope

- account-wide R2 token 재사용
- iOS에 R2 credential 또는 permanent URL
- production bucket live write
- Cloudflare DNS/NPM 변경
- 대화에 Access Key/Secret 받기

## Acceptance criteria

- [x] domain media test는 MemoryObjectStore로 통과한다.
- [x] R2 Adapter는 put/get/delete/exists와 404→null, oversized get 거부를 테스트한다.
- [x] `R2_ENABLED=true`인데 key가 비면 애플리케이션이 기동하지 않는다.
- [x] `deploy-development`만 `secrets.R2_*`를 참조한다.
- [x] PR CI/iOS workflow는 R2 secret을 받지 않는다.

## Test seam

- `R2ObjectStore`의 S3 client 경계
- `MediaConfiguration`의 enabled/disabled 선택

## Verification

```text
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.media.R2ObjectStoreTests" --no-daemon --console=plain
powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1
```

## Evidence

- 실행 명령: `.\gradlew.bat test --tests com.ansandy.moneysnap.media.R2ObjectStoreTests --tests com.ansandy.moneysnap.media.MediaConfigurationTests`; `scripts\validate-cicd.ps1`
- 결과: Gradle BUILD SUCCESSFUL; `Money Snap CI/CD static contract: OK`
- 남은 외부 작업: Cloudflare R2 API token을 `server-development`에 등록해야 live PUT이 켜진다.

## Agent rules impact

- 영향 여부: yes
- 근거: development CD가 R2 runtime secret을 쓸 수 있음을 PR CI와 구분해야 한다.
- 처리 결과: `AGENTS.md`의 secret 주입 문장을 R2가 deploy-only임을 포함하도록 갱신한다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped if graph tools unavailable
- findings와 처리 결과:

## Decisions and risks

- bucket-scoped S3 token 값은 GitHub environment secret으로만 등록한다.
- live R2 PUT/GET contract는 secret이 있는 환경에서만 실행한다.

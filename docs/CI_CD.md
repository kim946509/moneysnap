# Money Snap CI/CD 운영 계약

> 상태: Ubuntu development CD active, Apple runtime secret은 `server-development` environment로만 주입, iOS TestFlight는 `ios-testflight` environment
>
> 기준일: 2026-08-17

## 배포 lane

| Lane | 실행 위치 | Trigger | 결과 |
|---|---|---|---|
| server CI | GitHub-hosted `ubuntu-latest` | server·API contract 관련 pull request, `main` push, manual | Java 21 test, production JAR, immutable Docker image와 SHA-256 archive |
| server development CD | GitHub-hosted `ubuntu-latest` → SSH Ubuntu Docker host | server CI가 성공한 `main` push만 | checksum 검증, `9090` origin 교체, container health gate, 실패 시 이전 image rollback |
| iOS CI | GitHub-hosted `macos-15` | iOS·contract pull request, `main` push, manual | Simulator ad-hoc signed unit+UI test, unsigned build-once 393x852 visual evidence, 실패 `.xcresult` |
| iOS TestFlight CD | GitHub-hosted `macos-26` / Xcode 26 | 성공한 `main` iOS CI **push** 또는 `main` manual | App Store Connect API key로 archive 후 internal TestFlight 업로드 |
| DNS/NPM·모니터링 | 승인된 infrastructure 작업 | hostname, proxy 또는 scrape 설정 변경 | Cloudflare DNS, Nginx Proxy Manager, Prometheus·Grafana |

Application CD는 Cloudflare DNS, Nginx Proxy Manager, Prometheus 설정을 만들거나 변경하지 않는다. 이 리소스는 application image rollback과 독립된 infrastructure lifecycle로 운영한다.

## 서버 GitHub Actions

`.github/workflows/server-ci-cd.yml`은 다음 경계를 강제한다.

- workflow 전체 권한은 `contents: read`뿐이다.
- 모든 외부 action은 전체 commit SHA로 고정하고 Dependabot으로 갱신한다.
- pull request CI와 server test/package job은 Neon, SSH, R2, Cloudflare 또는 Apple secret을 받지 않는다.
- `deploy-development`는 `server-development`의 Neon·SSH·Apple runtime secret이 비어 있으면 실패하고, `.p8` 개행은 env 한 줄의 literal `\n`으로 정규화한 뒤 `/opt/moneysnap/runtime.env`에만 쓴다. `/opt/moneysnap/.env`는 Compose interpolation stub다.
- `contracts/**` 변경도 server와 iOS lane을 함께 실행한다.
- server 기본 `test`는 `contracts/openapi/moneysnap-v1.yaml`과 `contracts/examples/v1/**`의 semantic OpenAPI 3.1/Draft 2020-12 gate를 실행하고, iOS native test는 같은 canonical fixture resource를 decode한다.
- test와 `bootJar`가 통과한 뒤 digest-pinned Java runtime으로 Docker image를 만든다.
- image는 `docker save`와 gzip으로 고정하고 SHA-256 manifest와 함께 7일 보관한다.
- deployment job은 `push`와 `refs/heads/main`을 동시에 검사하고 `server-development` environment를 요구한다.
- GitHub-hosted deployment runner는 pinned host key와 private key로 tested image만 Ubuntu staging에 전송한다. host/user/port/key의 UTF-8 BOM과 CR을 제거하고, private key가 `ssh-keygen`으로 loadable하지 않으면 전송 전에 실패한다.
- runtime secret file은 artifact에 포함하지 않으며 원격 `/opt/moneysnap/runtime.env`에 mode `600`으로 설치한다.
- main deployment는 cancel하지 않고 concurrency로 직렬화한다.

## Ubuntu Docker origin

상세 파일은 `infra/ubuntu/`가 소유한다.

1. `server/scripts/test-docker-deployment.sh`가 정상 배포와 health 실패 rollback을 fake Docker로 검증한다.
2. `infra/ubuntu/deploy.sh`가 image archive checksum을 확인하고 `docker load`한다.
3. `infra/ubuntu/compose.yaml`은 `moneysnap-server`를 non-root, read-only filesystem, dropped capabilities로 실행한다.
4. private host `192.168.1.102:9090`은 application `8080`으로 전달한다. management `9091`은 외부 publish 없이 Docker network `main`에만 노출한다.
5. container healthcheck가 `127.0.0.1:9091/actuator/health`의 성공을 확인한 뒤에만 release state를 기록한다.
6. 실패하면 이전 container image로 Compose를 다시 올린다. DB down migration은 자동화하지 않는다.

Spring runtime과 Flyway는 development Neon의 서로 다른 pooled/direct credential을 사용한다. schema 변경은 이전 image와 호환되는 expand-first 순서를 feature AC로 가져야 한다.

## Public route와 monitoring

- public API: `https://moneysnap-server.ansandy.co.kr/`
- Nginx Proxy Manager upstream: Ubuntu private host `9090`
- public smoke: `/`가 `{"service":"moneysnap-api","status":"UP"}`를 반환한다.
- public actuator: 차단한다. management endpoint는 `main` network의 `moneysnap-server:9091`에서만 사용한다.
- Prometheus job: `moneysnap_server`, target `moneysnap-server:9091`, metrics path `/actuator/prometheus`
- Grafana health: `https://monitor.ansandy.co.kr/api/health`
- Prometheus host publish는 application `9090`과 충돌하지 않도록 `127.0.0.1:9092`이며 container network 안에서는 계속 `prometheus:9090`이다.

## GitHub 설정 계약

Environment `server-development`는 `main` 전용 branch policy를 유지하고 다음 secret만 보유한다.

- `NEON_RUNTIME_DATABASE_URL`
- `NEON_RUNTIME_DATABASE_USERNAME`
- `NEON_RUNTIME_DATABASE_PASSWORD`
- `NEON_MIGRATION_DATABASE_URL`
- `NEON_MIGRATION_DATABASE_USERNAME`
- `NEON_MIGRATION_DATABASE_PASSWORD`
- `SERVER_HOST`
- `SERVER_SSH_PORT`
- `SERVER_SSH_USER`
- `SERVER_SSH_PRIVATE_KEY`
- `SERVER_SSH_KNOWN_HOSTS`
- `APPLE_AUTH_ENABLED`
- `APPLE_CLIENT_ID`
- `APPLE_TEAM_ID`
- `APPLE_KEY_ID`
- `APPLE_PRIVATE_KEY_P8`
- `APPLE_REFRESH_TOKEN_ENCRYPTION_KEY`
- `R2_ENABLED`
- `R2_BUCKET`
- `R2_ENDPOINT`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`

Apple `.p8`과 refresh-token 암호화 key는 대화·commit·PR log에 붙이지 않는다. 로컬 파일에서 environment secret만 등록한다.

```text
gh secret set APPLE_PRIVATE_KEY_P8 --env server-development < AuthKey_<KEY_ID>.p8
```

`.p8`은 여러 줄 그대로 넣어도 되며 CD가 env 한 줄로 정규화한다. `APPLE_AUTH_ENABLED`는 `true` 또는 `false`만 허용한다.

Repository는 public이며 Secret Scanning과 Push Protection을 활성화한다. `main`은 PR, linear history와 conversation resolution을 요구하고 force-push·delete를 금지한다. 대화나 로그에 노출된 deployment credential은 회전하고, 장기적으로 root 대신 최소 권한 deploy account로 축소한다.

Environment `ios-testflight`는 `main` 전용 branch policy를 유지하고 다음 secret만 보유한다. `server-development`와 섞지 않는다.

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_API_KEY_P8`

값은 대화·Git에 붙이지 않는다. API key는 App Store Connect → Users and Access → Integrations의 **Team** key여야 한다. Individual/app-scoped key는 `-allowProvisioningUpdates`에 쓸 수 없다. key에는 Certificates, Identifiers & Profiles 접근과 cloud-managed Apple Distribution signing 권한이 있어야 한다. Admin 또는 App Manager 역할만으로는 부족하다.

```text
gh secret set APPLE_TEAM_ID --env ios-testflight
gh secret set APP_STORE_CONNECT_ISSUER_ID --env ios-testflight
gh secret set APP_STORE_CONNECT_KEY_ID --env ios-testflight
gh secret set APP_STORE_CONNECT_API_KEY_P8 --env ios-testflight < AuthKey_<KEY_ID>.p8
```

## iOS CI와 TestFlight CD

GitHub Actions의 `.github/workflows/ios-ci.yml`은 Apple 개발 credential·provisioning 없이 `macos-15`의 Xcode 16.4, iPhone 16, iOS 18.5에서 Xcode 기본 ad-hoc 서명으로 `bash ios/scripts/test.sh`의 unit test와 non-parallel UI test를 실행한다. Keychain을 쓰지 않는 unsigned app을 한 번 build/install하고 manifest 순서의 Figma Home `9:2`, My `77:798`를 393x852로 캡처한다. 각 app/reference/overlay/diff/report는 한 화면이 threshold를 넘더라도 모두 생성한 뒤 실패를 집계하며 7일 보관한다.

TestFlight CD는 `.github/workflows/ios-testflight.yml`이 소유한다. 성공한 `main` **push** iOS CI 또는 `main`의 `workflow_dispatch`에서만 실행하고 `ios-testflight` environment secret만 사용한다. PR에서 성공한 iOS CI는 TestFlight를 시작하지 않는다. PR과 `ios-ci.yml`에는 App Store Connect API key를 넣지 않는다. Bundle ID는 `com.ansandy.moneysnap`이다. Sign in with Apple runtime `.p8`은 서버 `server-development` secret이며 TestFlight 업로드 키와 분리한다. 레포는 분리하지 않는다.

첫 업로드는 secret 등록 뒤 Actions에서 `iOS TestFlight` workflow를 `main`에 `workflow_dispatch`한다. 업로드 후 App Store Connect에서 Internal Tester를 넣고 아이폰 TestFlight에서 설치한다.

## 현재 활성화 상태

| 항목 | 상태 |
|---|---|
| GitHub repository | public |
| server workflow source와 정적 검증 | Ubuntu Docker/SSH CD 계약 준비 완료 |
| Ubuntu `moneysnap-server` | `9090`, `main` network, healthy |
| Money Snap public HTTPS route | `/` 200, public actuator 403 |
| Prometheus Money Snap target | `up=1` |
| Grafana public health | HTTP 200 |
| GitHub `server-development` environment | `main` policy, Neon/SSH 11개, Apple runtime secret 6개, R2 secret 5개 |
| Secret Scanning / Push Protection | enabled / enabled |
| GitHub remote workflow | 변경 push 후 `main` deployment 검증 필요 |
| iOS GitHub native/visual CI | 활성화 |
| iOS TestFlight GitHub CD | environment·`main` policy 생성. secret 등록 후 첫 업로드 |

이전 Windows self-hosted/named Tunnel 조사는 `docs/CI_CD_RESEARCH.md`에 역사적 근거로 남기되 현재 실행 계약으로 사용하지 않는다.

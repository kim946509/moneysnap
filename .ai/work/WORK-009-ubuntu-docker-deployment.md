---
id: WORK-009
status: complete
depends_on: [WORK-007]
owner: codex
---

# Ubuntu Docker 배포와 모니터링 복구

## Intent

Money Snap Spring Boot 서버를 개발자 소유 Ubuntu 서버의 Docker 환경에 안전하게 배포하고 기존 Prometheus·Grafana 운영 경로와 GitHub Actions CD를 연결한다.

## In scope

- GitHub-hosted Ubuntu에서 검증된 Docker image artifact를 만들고 SSH로 배포하는 CD
- Ubuntu host port `9090`, container port `8080`, external Docker network `main` 계약
- Neon development runtime·migration secret 주입
- 기존 Prometheus host port 충돌 해소와 Money Snap scrape target 추가
- Grafana 외부 접속 장애 진단·복구
- `moneysnap-server.ansandy.co.kr` HTTPS health smoke
- GitHub Secret Scanning과 Push Protection 활성화
- Windows self-hosted deployment 계약 제거 및 기준 문서·`AGENTS.md` 동기화

## Out of scope

- Neon schema 또는 제품 기능 변경
- Cloudflare Containers, named Tunnel, Workers Paid 활성화
- production Neon project 사용
- iOS/Xcode Cloud 변경
- 기존 Midas/MySQL 컨테이너 변경

## Acceptance criteria

- [x] `moneysnap-server` 컨테이너가 Ubuntu에서 restart policy와 healthcheck를 가지고 실행된다.
- [x] 컨테이너는 `main` 네트워크에 연결되고 private host `192.168.1.102:9090`에서 container `8080`으로 전달된다.
- [x] 기존 Prometheus·Grafana·node-exporter가 계속 동작하며 Prometheus가 Money Snap metrics/health target을 관찰할 수 있다.
- [x] `https://monitor.ansandy.co.kr/api/health`가 HTTP 200을 반환한다.
- [x] `https://moneysnap-server.ansandy.co.kr/`가 최소 상태 JSON을 반환하고 public origin에서 actuator path는 노출되지 않는다.
- [x] GitHub Actions가 public repository의 PR에서는 secret이나 SSH를 사용하지 않고 `main` push에서만 Ubuntu deployment를 수행한다.
- [x] 필요한 SSH·Neon 값은 GitHub environment secret에만 있고 저장소와 artifact에는 없다.
- [x] GitHub Secret Scanning과 Push Protection이 활성화된다.

## Test seam

- repository seam: `scripts/validate-cicd.ps1`가 Docker/SSH/main-only/security contract를 검증한다.
- container seam: Docker Compose render와 container healthcheck가 port·network·secret-file contract를 검증한다.
- public seam: Money Snap HTTPS `/`와 Grafana `/api/health`가 실제 외부 경로를 검증하고 public actuator가 차단되는지 확인한다.

## Verification

```text
powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1
cd server; .\gradlew.bat test bootJar --no-daemon --console=plain
docker compose -f infra/ubuntu/compose.yaml config
curl https://monitor.ansandy.co.kr/api/health
curl https://moneysnap-server.ansandy.co.kr/
```

## Evidence

- `powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1`: `Money Snap CI/CD static contract: OK`
- `cd server; .\gradlew.bat test bootJar --no-daemon --console=plain`: `BUILD SUCCESSFUL`
- Ubuntu `bash server/scripts/test-docker-deployment.sh`: 정상 deploy와 이전 image·Compose·env rollback 모두 `OK`
- Ubuntu `deploy.sh ... manual-work009-private-bind`: checksum `OK`, container `Healthy`, `192.168.1.102:9090 -> 8080`
- external smoke: Money Snap `/` 200, public `/actuator/health` 403, Grafana `/api/health` 200
- Prometheus query `up{job="moneysnap_server"}`: instance `moneysnap-server:9091`, value `1`
- GitHub `server-development`: required secret 11개 등록 확인
- GitHub repository security: Secret Scanning `enabled`, Push Protection `enabled`
- tracked private-key marker scan과 `git diff --check`: 통과

## Agent rules impact

- 영향 여부: yes
- 근거: 서버 실행 위치, CI/CD runner, Cloudflare 역할과 검증 명령이 Windows Tunnel origin에서 Ubuntu Docker/NPM origin으로 변경된다.
- 처리 결과: ADR, Architecture, CI/CD, infra/server 문서를 먼저 갱신한 뒤 `AGENTS.md` 현재 단계·규칙·명령을 동기화함

## Code Review Graph

- 코드 변경 여부: yes
- graph action: existing graph incremental update
- base: c982e03
- risk: graph score low 0.40, 운영 판단상 high-risk deployment로 실제 remote smoke 병행
- findings와 처리 결과: 7개 test gap 표시는 shell/MockMvc test 연결 한계다. `deploy_image`는 Ubuntu fake-Docker 정상/rollback test, `ApiSecurityConfiguration`과 `ServiceStatusController`는 `MoneySnapServerApplicationTests`로 검증했다. actionable finding 없음.

## Decisions and risks

- 사용자 승인: 제공한 SSH root key 사용, 개인 서버 변경, GitHub secret 등록, Cloudflare/NPM public route, Secret Scanning/Push Protection 활성화를 명시적으로 승인함.
- 현재 Grafana 장애 원인은 `monitor.ansandy.co.kr` A record가 잘못된 공인 IP를 가리킨 것이며, DNS 수정 후 외부 health 200으로 복구됨.
- host `9090`은 기존 Prometheus가 점유하므로 Prometheus의 host publish만 이동하고 Docker network 내부 `prometheus:9090`은 유지한다.
- 대화에 노출된 root credential은 작업 후 회전이 필요하나 사용자가 이번 작업에서 기존 key 사용을 명시적으로 선택했다.

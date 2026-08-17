---
id: WORK-034
status: proposed
depends_on: [WORK-033]
owner: codex
---

# Stage 10 development 배포와 live smoke

## Intent

승인된 release candidate를 정확한 immutable artifact로 development Ubuntu·Neon dev·R2 dev 경계에만 배포하고 public route, 보안, 관측성과 rollback을 실제 환경에서 검증한다.

## In scope

- 실행 직전 다시 승인받은 외부 변경 경계와 exact candidate SHA·Docker digest·rollback image 고정
- GitHub Actions의 성공한 `main` server artifact와 checksum을 통한 Ubuntu Docker development 배포
- `moneysnap-server`의 private host `192.168.1.102:9090`, external `main` network, management container port `9091` 계약
- development Neon pooled runtime/direct migration 분리와 expand-first migration smoke
- private `moneysnap-media-dev` R2 adapter PUT/GET/DELETE 또는 app media smoke와 test object cleanup
- `https://moneysnap-server.ansandy.co.kr/`, protected API auth rejection/authorized path, public actuator denial
- Prometheus `moneysnap_server` target과 Grafana health·server metric 확인
- 이전 immutable image rollback→candidate reapply drill without DB down migration
- Ubuntu restart/health, non-root/read-only/capability/secret-file runtime contract와 evidence

## Out of scope

- `moneysnap-prod`, `moneysnap-media-prod` 또는 실제 사용자 production data 접근
- Cloudflare DNS, Nginx Proxy Manager, firewall, Prometheus/Grafana configuration 생성·변경·재시작; 문제가 있으면 별도 infrastructure 승인 작업으로 분리한다.
- 새로운 Cloudflare Container/Tunnel/Worker, 비용 리소스 또는 public App Store origin 전환
- repository·artifact에 SSH/Neon/R2/Apple secret 기록, 로그에 secret 출력 또는 test auth backdoor 추가
- Apple explicit App ID·Sign in with Apple key/certificate, Xcode Cloud, archive, TestFlight와 실제 iPhone 검증; 별도 credential/2FA·사용자 실행 승인 gate다.
- production DB down migration, destructive restore와 운영 데이터 삭제

## Acceptance criteria

- [ ] WORK-033이 ready인 exact candidate SHA·image digest·SHA-256 archive와 known-good previous image를 기록하고, 실행 직전 사용자가 Ubuntu/Neon dev/R2 dev의 외부 변경 및 잠깐의 rollback drill을 다시 명시 승인한다.
- [ ] 배포 source는 성공한 `main` CI artifact 하나뿐이고 Ubuntu가 checksum을 검증한 뒤 같은 digest를 실행한다. local rebuild, mutable `latest` 또는 미검증 archive를 사용하지 않는다.
- [ ] runtime과 Flyway는 `moneysnap-dev`의 각각 pooled 최소권한/direct owner credential만 사용하고 prod endpoint·role·project ID는 process environment와 migration log에 존재하지 않는다.
- [ ] current expand-first migration이 dev data를 보존하며 app health 전에 완료되고, 실패하면 candidate를 healthy로 확정하지 않으며 DB down migration을 자동 실행하지 않는다.
- [ ] container는 이름 `moneysnap-server`, external Docker network `main`, host `192.168.1.102:9090`→app `8080`, host publish 없는 management `9091` 계약을 만족한다.
- [ ] `docker inspect`에서 non-root, read-only root filesystem, dropped capabilities, `no-new-privileges`, resource limit와 `unless-stopped`가 유지되고 `/opt/moneysnap/.env`는 owner root·mode `600`이다. secret 값 자체는 evidence에 출력하지 않는다.
- [ ] public `GET /`가 HTTPS 200과 exact `{"service":"moneysnap-api","status":"UP"}`를 반환한다.
- [ ] bearer 없는 protected MVP API와 malformed/revoked token은 canonical `401 SESSION_REJECTED`를 반환하고 개인·group·media data를 노출하지 않는다.
- [ ] 정상 인증 positive smoke는 normal Sign in with Apple 경계에서 얻은 development session이 있을 때만 실행한다. Apple activation이 별도 승인되지 않았으면 credential을 위조하거나 backdoor를 만들지 않고 positive auth/device 항목을 `credential-gated`로 분리 기록한다.
- [ ] public `/actuator`, `/actuator/health`, `/actuator/prometheus`는 403/404로 차단되고 host의 `9091`은 publish되지 않지만 `main` network 내부 health·metrics는 200이다.
- [ ] `moneysnap-media-dev`만 대상으로 고유 prefix의 bounded JPEG contract object를 쓰고 checksum과 private GET을 확인한 뒤 삭제한다. test 전후 prefix object count가 같고 public URL·credential은 생성하지 않는다.
- [ ] Prometheus query `up{job="moneysnap_server"}`가 candidate container에 대해 `1`이고 application request/health metric timestamp가 smoke 이후 갱신되며 Grafana `https://monitor.ansandy.co.kr/api/health`가 200이다.
- [ ] known-good previous immutable image로 rollback한 뒤 같은 expanded schema·secret에서 `/`와 protected-route rejection이 정상이고, candidate digest를 다시 적용한 뒤 모든 health/smoke가 재통과한다. rollback 중 DB down migration을 실행하지 않는다.
- [ ] host 또는 container restart 뒤 `unless-stopped`, main network와 health가 복구되고 Nginx Proxy Manager public route·Prometheus scrape가 다시 정상이다.
- [ ] deployment와 smoke log/artifact에 `.env`, private key, database URL/password, R2 secret, Apple credential, bearer/refresh token 원문이 없고 GitHub environment secret은 deployment step 밖으로 전달되지 않는다.
- [ ] live smoke evidence가 UTC/KST timestamps, candidate/previous digest, migration version, sanitized curl status, R2 cleanup, Prometheus/Grafana, rollback/reapply 결과와 남은 Apple credential gate를 기록한다.
- [ ] 실제 iPhone Sign in with Apple, Xcode signing/archive와 internal TestFlight는 explicit App ID·key·2FA·Mac/Xcode 승인 후 별도 작업으로 실행하며 이 server live-smoke 완료와 동일시하지 않는다.

## Test seam

- preflight seam: 외부 접속 전에 candidate SHA/digest/checksum, dev-only resource IDs, known_hosts, rollback digest와 approval timestamp가 하나라도 없으면 중단한다.
- deployment seam: WORK-033 candidate SHA·image digest·checksum과 green evidence가 변경되지 않았는지 preflight로 확인한 뒤 실제 development deploy를 한 번 수행한다. 어느 값이라도 바뀌면 WORK-033 새 candidate/full gate로 돌아간다.
- boundary seam: public `/`, protected API 401, actuator denial과 internal management 200을 같은 candidate timestamp로 비교한다.
- data seam: Neon dev에는 식별 가능한 nonproduction smoke record만 쓰고 transaction cleanup을 확인하며, R2 dev object는 unique prefix와 `finally` cleanup을 사용한다.
- rollback seam: 이전 digest→candidate digest 전환과 같은 expanded schema의 양방향 app boot만 검증하고 migration version을 뒤로 돌리지 않는다.
- monitoring seam: request 전후 Prometheus sample timestamp/target health와 Grafana API health를 확인해 단순 process up과 실제 scrape를 구분한다.
- WORK-033 full long test는 같은 immutable candidate에서 중복 실행하지 않고 SHA·digest·checksum·evidence 불변성을 확인한다. live finding이 코드 수정을 요구하면 운영 중 patch하지 않고 새 TDD work item과 새 candidate로 돌아간다.

## Verification

```text
bash server/scripts/test-docker-deployment.sh
MONEYSNAP_IMAGE=moneysnap-server:validation MONEYSNAP_ENV_FILE=/path/to/runtime.env docker compose -f infra/ubuntu/compose.yaml config --quiet
bash scripts/release/preflight-live-smoke.sh
bash scripts/release/run-development-live-smoke.sh
curl --fail https://moneysnap-server.ansandy.co.kr/
curl --fail https://monitor.ansandy.co.kr/api/health
git diff --check
```

`preflight-live-smoke.sh`와 `run-development-live-smoke.sh`는 WORK-034 실행 전에 구현·red fixture 검증할 대상이다. 후자는 sanitized artifact로 container hardening, internal actuator, dev-only R2 cleanup, Prometheus timestamp, rollback/reapply/restart와 log secret scan을 한 번에 기록하며, 스크립트가 존재하기 전에는 해당 AC evidence를 주장하지 않는다.

## Evidence

- 실행 명령: 구현 전 Ubuntu/Neon/R2/CI/CD canonical contract 확인, 실제 외부 명령은 재승인 뒤 sanitized form으로 기록 예정
- 결과: 2026-08-13 작업 항목 작성 시점에는 외부 변경·배포를 실행하지 않았고 live 완료를 주장하지 않음
- 리뷰: 사용자가 전체 MVP와 배포 흐름 진행을 포괄 승인했지만, `AGENTS.md` 승인 경계에 따라 WORK-034의 Ubuntu·Neon dev·R2 dev 변경과 rollback drill은 실행 직전 다시 명시 승인받는다.

## Agent rules impact

- 영향 여부: yes
- 근거: 실제 development release SHA, live infrastructure 상태와 운영 검증 결과가 현재 단계·배포 상태·검증 설명을 바꾼다.
- 처리 결과: 실행 승인 전에는 `AGENTS.md`를 완료 상태로 바꾸지 않는다. 성공 후 canonical CI/CD·infra 문서를 먼저 갱신하고 sanitized evidence와 함께 현재 단계만 동기화한다.

## Code Review Graph

- 코드 변경 여부: 기본적으로 no (승인된 immutable candidate의 운영 검증)
- graph action: deploy 전 WORK-033 candidate graph 최신성 확인; 운영 evidence만 생기면 skipped
- base: WORK-033 exact candidate SHA
- risk: high (external deployment, dev data/object mutation, temporary rollback, secret handling)
- findings와 처리 결과: live finding이 application code 변경을 요구하면 그 자리에서 수정하지 않고 새 작업 항목에서 TDD→incremental graph update→새 WORK-033 candidate를 만든 뒤 다시 승인받는다.

## Decisions and risks

- 2026-08-13의 포괄 진행 승인은 계획 작성 범위를 열지만, 실제 외부 시스템 변경 승인을 대체하지 않는다.
- deployment는 application image와 runtime env만 소유하며 DNS/NPM/monitoring lifecycle을 고치지 않는다.
- positive Apple authentication을 위해 debug endpoint·직접 DB session insert·임의 JWT를 만들지 않는다. credential gate는 명시적으로 남긴다.
- dev와 prod 이름이 비슷하므로 preflight에서 project/bucket identifier를 exact allowlist로 검사하고 prod가 보이면 즉시 중단한다.
- rollback drill은 짧은 development 중단 가능성이 있으며 실행 승인에 그 영향을 포함한다. 이전 artifact가 없거나 schema compatibility evidence가 없으면 drill을 수행하지 않는다.
- Apple device/TestFlight는 사용자 보유 계정을 사용하더라도 signing credential·2FA·Mac/Xcode activation이 필요한 독립된 외부 작업이다.

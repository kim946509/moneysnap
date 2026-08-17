# Ubuntu Docker development origin

Money Snap development API는 기존 Ubuntu host의 Docker와 `main` monitoring network를 재사용한다.

## Runtime contract

- container: `moneysnap-server`
- image: GitHub commit SHA tag
- application: private host `192.168.1.102:9090` → container `8080`
- management: container `9091`, host publish 없음
- network: existing external bridge `main`
- restart: `unless-stopped`
- secret file: `/opt/moneysnap/runtime.env`, owner root, mode `600`
- compose interpolation stub: `/opt/moneysnap/.env`
- public route: `https://moneysnap-server.ansandy.co.kr/`

`compose.yaml`은 non-root user, read-only root filesystem, tmpfs, dropped Linux capabilities와 `no-new-privileges`를 강제한다. `/actuator/health`와 `/actuator/prometheus`는 management port에서만 사용한다.

## Deployment

GitHub Actions가 test와 `bootJar`를 통과한 image를 archive하고 SHA-256 manifest와 함께 전송한다. `deploy.sh`은 checksum과 `main` network를 확인하고 Compose health gate를 통과한 뒤 release를 확정한다. 실패 시 이전 image, Compose와 runtime env를 함께 복원한다.

필요한 GitHub environment secret 이름은 `docs/CI_CD.md`가 소유한다. 실제 SSH key, known_hosts와 Neon connection은 이 디렉터리에 저장하지 않는다.

## Monitoring

`prometheus-moneysnap-job.yaml`을 기존 Prometheus `scrape_configs` 아래에 한 번 추가한다. target은 Docker DNS의 `moneysnap-server:9091`이다.

기존 Prometheus의 container port는 계속 `9090`이고 host publish만 `127.0.0.1:9092`로 이동한다. Grafana data source가 `prometheus:9090`을 사용하므로 내부 연결은 바뀌지 않는다.

## Verification

```bash
bash server/scripts/test-docker-deployment.sh
MONEYSNAP_IMAGE=moneysnap-server:validation \
MONEYSNAP_ENV_FILE=/opt/moneysnap/runtime.env \
docker compose -f infra/ubuntu/compose.yaml config --quiet
curl --fail http://192.168.1.102:9090/
curl --fail http://127.0.0.1:9092/api/v1/query?query=up%7Bjob%3D%22moneysnap_server%22%7D
```

DNS, Nginx Proxy Manager와 Prometheus/Grafana 변경은 application CD 범위 밖의 승인된 infrastructure 작업으로 유지한다.

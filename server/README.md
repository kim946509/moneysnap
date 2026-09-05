# Money Snap server

Java 21과 Spring Boot 4.1.0으로 만든 modular monolith API scaffold다.

## 실행

개발 실행 전 `.env.example`의 key를 저장소 밖 환경변수로 주입한다. 기본 DB는 `./data/moneysnap.db` SQLite 파일이며 Neon/H2로 자동 대체하지 않는다.

```powershell
.\gradlew.bat bootRun
```

기본 address는 `127.0.0.1`이다. Docker 배포에서는 application `8080`과 management `9091`을 분리하며 public API hostname에서는 actuator path를 노출하지 않는다.

## 검증

```powershell
.\gradlew.bat test
.\gradlew.bat bootJar
```

production artifact 이름은 `build/libs/moneysnap-server.jar`로 고정한다.

통합 테스트는 임시 SQLite 파일을 사용하며 Docker Postgres와 Neon에 접속하지 않는다.

## 환경 계약

- runtime/Flyway: `MONEYSNAP_SQLITE_URL`, 기본 `./data/moneysnap.db`
- origin 배포: `/var/lib/moneysnap/moneysnap.db` (host `/opt/moneysnap/data`)
- secret: `.env.*.local`, CI 또는 배포 secret에만 저장. DB 파일 자체는 볼륨이다.

## CI/CD

- pull request와 `main` push: `.github/workflows/server-ci-cd.yml`이 Java 21 test·bootJar와 immutable Docker image archive를 만든다.
- deployment behavior: `scripts/test-docker-deployment.sh`가 정상 health gate와 실패 시 이전 image rollback을 검증한다.
- development deploy: 성공한 `main` run만 GitHub-hosted Ubuntu에서 pinned SSH host로 artifact를 전송한다.
- container contract: `Dockerfile`, `infra/ubuntu/compose.yaml`
- deploy/rollback: `infra/ubuntu/deploy.sh`

상세 GitHub environment secret과 운영 경계는 `docs/CI_CD.md`를 따른다. DNS, Nginx Proxy Manager와 Prometheus 설정은 server release workflow가 관리하지 않는다.

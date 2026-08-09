# Money Snap server

Java 21과 Spring Boot 4.1.0으로 만든 modular monolith API scaffold다.

## 실행

개발 실행 전 `.env.example`의 key를 저장소 밖 환경변수로 주입한다. 기본 실행은 PostgreSQL 연결이 없으면 실패하며 로컬 H2로 자동 대체하지 않는다.

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

현재 bootstrap test는 외부 Neon이나 Docker를 사용하지 않는다. PostgreSQL constraint·Flyway·transaction이 필요한 feature integration test에서만 `TestcontainersConfiguration`의 PostgreSQL 18 container를 가져온다.

## 환경 계약

- runtime: `NEON_RUNTIME_DATABASE_*`에 Neon pooled endpoint와 `moneysnap_app`
- Flyway: 별도 `NEON_MIGRATION_DATABASE_*`에 Neon direct endpoint와 owner role
- test: feature integration test에서만 PostgreSQL 18 Testcontainers
- secret: `.env.*.local`, CI 또는 배포 secret에만 저장

runtime 또는 migration 변수 하나라도 빠지면 production startup은 실패한다. Flyway가 runtime datasource로 묵시적으로 fallback하지 않도록 두 연결을 `application.properties`에서 각각 명시한다.

## CI/CD

- pull request와 `main` push: `.github/workflows/server-ci-cd.yml`이 Java 21 test·bootJar와 immutable Docker image archive를 만든다.
- deployment behavior: `scripts/test-docker-deployment.sh`가 정상 health gate와 실패 시 이전 image rollback을 검증한다.
- development deploy: 성공한 `main` run만 GitHub-hosted Ubuntu에서 pinned SSH host로 artifact를 전송한다.
- container contract: `Dockerfile`, `infra/ubuntu/compose.yaml`
- deploy/rollback: `infra/ubuntu/deploy.sh`

상세 GitHub environment secret과 운영 경계는 `docs/CI_CD.md`를 따른다. DNS, Nginx Proxy Manager와 Prometheus 설정은 server release workflow가 관리하지 않는다.

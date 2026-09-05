---
id: WORK-055
status: complete
depends_on: []
owner: grok
---

# Origin SQLite로 Neon PostgreSQL 대체

## Intent

Neon CU-hour 한도와 상시 Spring 연결이 맞지 않으므로, PostgreSQL/Neon 전용 경로를 제거하고 Ubuntu origin의 Spring Boot와 같은 컨테이너에서 SQLite 파일 DB를 사용한다.

## In scope

- Flyway V1–V10을 SQLite dialect로 재작성
- Gradle PostgreSQL/Testcontainers 의존성 제거, sqlite-jdbc 도입
- 단일 datasource, Flyway는 runtime SQLite를 사용
- 통합 테스트는 메모리/임시 SQLite
- Docker 볼륨 `/var/lib/moneysnap`
- CI runtime.env에서 Neon secret 제거
- ADR-002/007, ARCHITECTURE, AGENTS.md, CI/CD 문서 동기화

## Out of scope

- Neon 데이터 dump/restore (compute 중단 시 이전 불가, 새 SQLite는 빈 DB)
- Turso/D1/원격 SQLite
- iOS 클라이언트 변경
- 사용자별 DB 분리

## Acceptance criteria

- [x] 서버 설정에 `NEON_*`와 분리된 Flyway URL이 없다.
- [x] `build.gradle`에 postgresql, flyway-database-postgresql, testcontainers-postgresql이 없다.
- [x] `.\gradlew.bat test`와 `bootJar`가 Docker Postgres 없이 통과한다.
- [x] compose는 SQLite 파일을 쓰는 writable volume을 마운트한다.
- [x] CD는 Neon secret을 요구하지 않는다.

## Test seam

- `SqliteConfigurationContractTests` (구 Neon 계약)
- Flyway가 SQLite에 V1–V10을 적용하는 통합 테스트
- 기존 identity/snap/group/media HTTP 통합 테스트가 Testcontainers 없이 통과

## Verification

```text
cd server; .\gradlew.bat test --no-daemon --console=plain
cd server; .\gradlew.bat bootJar --no-daemon --console=plain
powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1
git diff --check
```

## Evidence

- 실행 명령:
  - `cd server; .\gradlew.bat test bootJar --no-daemon --console=plain`
  - `powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1`
  - `git diff --check`
- 결과:
  - 162 tests, 0 failures, 0 errors, 0 skipped. `BUILD SUCCESSFUL` 56s.
  - `server/build/libs/moneysnap-server.jar` 61,685,980 bytes (2026-09-05 14:01).
  - CI/CD static contract: OK. `git diff --check` trailing whitespace 없음.
  - Windows `bash server/scripts/test-docker-deployment.sh`는 이 셸의 bash가 `pipefail`을 거부해 실행하지 못했다. GitHub-hosted Ubuntu CI가 같은 스크립트를 실행한다.
- 리뷰: Windows 세션에 code-review-graph MCP가 없어 그래프 리뷰는 생략. 제품 AC와 Gradle 증거가 기준이다.

## Agent rules impact

- 영향 여부: yes
- 근거: 데이터 엔진, 테스트 명령, 배포 secret, 아키텍처 불변이 Neon PostgreSQL에서 origin SQLite로 바뀐다.
- 처리 결과: `AGENTS.md`, ADR-002/006/007, `docs/ARCHITECTURE.md`, `docs/CI_CD.md`, `docs/TECHNICAL_DESIGN_PROPOSAL.md`, `infra/README.md`, `infra/ubuntu/README.md`를 같은 작업에서 동기화했다. `infra/neon/`은 폐기 인벤토리로 남긴다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
- base:
- risk: high
- findings와 처리 결과: Windows 세션에서 code-review-graph MCP 없음.

## Decisions and risks

- Neon 기존 데이터는 이전하지 않는다. 새 origin SQLite는 빈 스키마다.
- SQLite writer는 프로세스 하나. 컨테이너 복제는 하지 않는다.
- PostgreSQL `~` hex CHECK는 애플리케이션 검증에 맡기고 length CHECK만 유지한다.
- Instant는 ISO-8601 TEXT로 저장하고 microsecond로 truncate한다. UUID는 Java에서 생성한다.
- GitHub `server-development`의 남은 Neon secret과 Neon 콘솔 프로젝트 삭제는 저장소 밖 승인 작업이다.

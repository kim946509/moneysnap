# Neon PostgreSQL

## 생성된 환경

| 환경 | Project | Project ID | Branch | Region | PostgreSQL |
|---|---|---|---|---|---|
| development | `moneysnap-dev` | `lucky-dew-23275491` | `main` / `br-fragrant-scene-awvuskxw` | AWS us-east-1 | 18 |
| production | `moneysnap-prod` | `wandering-cell-45888626` | `main` / `br-floral-lab-a6nc6ujn` | AWS us-west-2 | 18 |

두 프로젝트는 Neon 조직 `대연`의 Free 플랜에 있다. 생성 당시 Free는 프로젝트당 0.5GB storage, 월 100 CU-hour, 5분 inactivity 후 scale-to-zero, 5GB public network transfer를 제공한다. 한도 도달 시 해당 월 compute가 중단될 수 있으므로 운영 DB 사용량을 별도로 관찰한다.

## 역할과 연결

- `neondb_owner`: schema owner. Flyway와 dump/restore 같은 admin 작업에만 direct endpoint로 연결한다.
- `moneysnap_app`: runtime 전용. `CONNECT`, schema `USAGE`, 이후 owner가 만든 table의 DML과 sequence 사용 권한만 가진다.
- pooled endpoint는 PgBouncer transaction mode다. Spring runtime에서 사용하고 Hikari pool 크기는 작은 값으로 제한한다.
- Flyway, `pg_dump`, `pg_restore`, session-level 설정이 필요한 작업은 direct endpoint를 사용한다.

로컬 비밀값은 Git에서 제외된 다음 파일에 있다.

- `.env.development.local`
- `.env.production.local`

운영 연결 정보는 다음 자동 배포 단계에서 배포 환경 secret으로 복사한다. 문서, commit, CI log 또는 artifact에 값을 노출하지 않는다.

Spring Boot에는 runtime용 `NEON_RUNTIME_DATABASE_URL`, `NEON_RUNTIME_DATABASE_USERNAME`, `NEON_RUNTIME_DATABASE_PASSWORD`와 migration용 `NEON_MIGRATION_DATABASE_URL`, `NEON_MIGRATION_DATABASE_USERNAME`, `NEON_MIGRATION_DATABASE_PASSWORD`를 각각 주입한다. migration 변수가 없을 때 Flyway가 runtime datasource로 fallback하지 않도록 서버 설정에서 두 연결을 모두 필수로 선언한다.

## Region 주의

연결된 provisioning 도구가 region 선택 인자를 제공하지 않아 생성 시 Neon 기본 region이 적용됐다. 폐쇄형 TestFlight에서는 이 구성을 사용하되, 공개 출시 전 latency 측정과 데이터 이전 계획을 포함해 한국 사용자와 origin에 가까운 region으로 재평가한다.

공식 기준: [Neon pricing](https://neon.com/pricing), [Connection pooling](https://neon.com/docs/connect/connection-pooling)

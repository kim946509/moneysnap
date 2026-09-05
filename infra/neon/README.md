# Neon PostgreSQL (retired)

origin SQLite로 대체됐다. Spring Boot는 `NEON_*` 환경변수를 읽지 않으며 GitHub `server-development`에도 Neon secret을 주입하지 않는다.

아래 프로젝트는 과거 인벤토리다. compute가 중단된 상태면 데이터를 이전하지 않고 Neon 콘솔에서 삭제해도 된다.

| 환경 | Project | Project ID | Branch | Region | PostgreSQL |
|---|---|---|---|---|---|
| development | `moneysnap-dev` | `lucky-dew-23275491` | `main` / `br-fragrant-scene-awvuskxw` | AWS us-east-1 | 18 |
| production | `moneysnap-prod` | `wandering-cell-45888626` | `main` / `br-floral-lab-a6nc6ujn` | AWS us-west-2 | 18 |

현재 데이터 계약은 `infra/ubuntu/README.md`의 SQLite 볼륨이다.

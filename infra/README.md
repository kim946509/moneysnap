# Money Snap infrastructure

애플리케이션과 CI/CD가 사용하는 인프라 계약을 보관한다. 비밀값은 Git에 커밋하지 않는다.

## 환경 분리

| 환경 | PostgreSQL | 목적 |
|---|---|---|
| 자동 테스트 | Testcontainers PostgreSQL 18 | 테스트 실행 중에만 일회성으로 기동해 실제 constraint/transaction 검증 |
| 기본 개발 | Neon `moneysnap-dev` | PC 간 동일한 개발 DB와 scale-to-zero |
| 운영 | Neon `moneysnap-prod` | 폐쇄형 TestFlight 운영 DB |

- `neon/`: Neon project, role, connection 계약
- `cloudflare/`: 생성된 private R2 dev/prod resource inventory, Tunnel 준비와 이후 배포 설정
- `windows/`: 무료 development Spring Boot origin과 self-hosted deployment runner 계약

## 비밀값 규칙

- `.env.*.local`은 Git에서 제외한다.
- 예제 파일에는 key와 설명만 두고 실제 password, connection string, API token을 넣지 않는다.
- Spring runtime은 pooled endpoint의 `moneysnap_app` 역할을 사용한다.
- Flyway, dump/restore와 admin 작업만 direct endpoint의 owner 역할을 사용한다.
- development Neon 비밀값은 GitHub `server-development` environment에서 deployment step에만 주입하고 Windows origin의 ACL 제한 secret files로 옮긴다. GitHub-hosted CI, 로그와 artifact에는 출력하지 않는다.

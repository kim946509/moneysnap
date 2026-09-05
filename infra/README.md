# Money Snap infrastructure

애플리케이션과 CI/CD가 사용하는 인프라 계약을 보관한다. 비밀값은 Git에 커밋하지 않는다.

## 환경 분리

| 환경 | 데이터 | 목적 |
|---|---|---|
| 자동 테스트 | 임시 SQLite 파일 | 테스트마다 Flyway와 constraint/transaction 검증 |
| 기본 개발 | 로컬 `server/data/moneysnap.db` | Windows/로컬 bootRun |
| development origin | Ubuntu 볼륨 `/opt/moneysnap/data/moneysnap.db` | 폐쇄형 TestFlight origin |

- `ubuntu/`: Docker development origin, SQLite 볼륨, rollback과 Prometheus scrape 계약
- `cloudflare/`: private R2 dev/prod resource inventory와 DNS 역할
- `apple/`: Bundle ID, Sign in with Apple 서버 secret, GitHub `ios-testflight` archive 계약
- `neon/`: 폐기된 Neon PostgreSQL 인벤토리. Spring runtime은 연결하지 않는다

## 비밀값 규칙

- `.env.*.local`은 Git에서 제외한다.
- 예제 파일에는 key와 설명만 두고 실제 password, connection string, API token을 넣지 않는다.
- SQLite 파일은 secret이 아니라 볼륨 데이터다. Apple·R2·SSH secret만 GitHub `server-development` environment에서 `deploy-development`에 주입하고 Ubuntu origin의 mode `600` `runtime.env`로 옮긴다. pull request CI, 로그와 artifact에는 출력하지 않는다.
- iOS TestFlight App Store Connect API key는 GitHub `ios-testflight` environment에만 두고 PR·iOS test job·`server-development`에 넣지 않는다.

# Cloudflare infrastructure

## 현재 provisioning 상태

- Wrangler OAuth login: 완료. account ID `6bcae71f04b38cc620c6d3b5bd68cd78`와 연결했고 OAuth 설정은 저장소 밖의 사용자 Wrangler config에 있다.
- R2: 활성 상태. private Standard bucket `moneysnap-media-dev`, `moneysnap-media-prod`를 APAC에 생성했다.
- 원격 검증: 두 bucket 모두 임시 객체 PUT/GET, SHA-256 비교, DELETE를 통과했고 최종 `0 objects / 0 B`다.
- public surface: `r2.dev`, custom domain, CORS, Data Catalog 모두 비활성 상태다.
- named Tunnel/DNS route: 미생성. Spring Boot 기본 origin은 `127.0.0.1:8080`으로 준비됐고 hostname·외부 노출 AC 승인 후 dev부터 만든다.
- Cloudflare Containers/Workers Paid: 비활성, 승인 전 금지
- application CI/CD: repository 설정은 준비됐지만 named Tunnel, DNS와 `cloudflared` service는 별도 infrastructure lifecycle로 유지한다.

2026-08-08 설정 시 계정 R2 전체 사용량은 이미 약 463.29 MB였다. 이는 Money Snap 전용 사용량이 아니며 기존 bucket은 변경하지 않았다. R2 Standard의 무료 사용량을 넘으면 사용량 과금될 수 있으므로 앱에서는 6 GB 경고와 7 GB 신규 업로드 차단을 구현하고 Dashboard 사용량과 대조한다.

## 준비된 리소스 계약

| 환경 | private bucket 이름 | storage class | location hint |
|---|---|---|---|
| development | `moneysnap-media-dev` | Standard | APAC |
| production | `moneysnap-media-prod` | Standard | APAC |

- 두 bucket은 public access와 `r2.dev`를 활성화하지 않는다.
- bucket별 Object Read & Write S3 credential을 분리하고 다른 bucket 접근을 허용하지 않는다. 기존 account-wide token은 재사용하지 않는다.
- iOS에는 R2 credential을 넣지 않는다. Spring Boot가 인증·quota 확인 후 짧은 presigned PUT/GET만 발급한다.
- native iOS와 server-to-R2 호출에는 browser CORS가 필요하지 않으므로 불필요한 CORS allowlist를 만들지 않는다.
- 비밀값은 `.env.*.local` 또는 다음 단계의 GitHub/배포 secret에만 저장한다.

비밀값이 아닌 실제 resource ID와 endpoint는 `resources.yaml`이 소유한다. S3 credential은 아직 만들지 않았다. 지금 장기 credential을 보관하지 않고 Spring Boot media Adapter와 R2 contract test가 생기는 작업에서 dev/prod bucket scope로 각각 발급한다.

## 남은 생성 순서

1. Spring Boot media Adapter 작업에서 dev/prod bucket-scoped credential을 각각 만들고 저장소 밖 secret에 등록한다.
2. Adapter의 S3-compatible contract test로 PUT/HEAD/GET/DELETE와 presigned URL 만료·권한을 검증한다.
3. hostname과 public actuator 차단 규칙을 확정한 뒤 `127.0.0.1:8080` origin에 `moneysnap-api-dev` named Tunnel과 DNS route를 만든다. 현재 zone을 사용한다면 후보 hostname은 `api.moneysnap.ansandy.co.kr`다.
4. Windows service 자동 기동과 Tunnel 재연결을 검증한다.
5. 공개 출시 전 origin과 production Tunnel/Containers 결정을 다시 승인받는다.

named Tunnel은 외부 노출·DNS 변경 작업 AC와 hostname이 아직 확정되지 않아 만들지 않았다. 빈 Tunnel credential을 미리 발급해 장기 보관하지 않는다.

GitHub Actions의 server deployment는 Spring Boot JAR과 Scheduled Task만 교체한다. tunnel 생성·삭제, hostname/DNS, tunnel token 발급·rotation과 `cloudflared` update는 수행하지 않는다. runtime tunnel token은 GitHub server artifact나 application secret과 섞지 않고 Windows ACL 제한 token file에만 둔다.

공식 기준: [R2 pricing](https://developers.cloudflare.com/r2/pricing/), [R2 get started](https://developers.cloudflare.com/r2/get-started/), [Create a Tunnel API](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel-api/)

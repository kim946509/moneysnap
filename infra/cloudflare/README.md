# Cloudflare infrastructure

## 현재 provisioning 상태

- Wrangler OAuth login: 완료. account ID `6bcae71f04b38cc620c6d3b5bd68cd78`와 연결했고 OAuth 설정은 저장소 밖의 사용자 Wrangler config에 있다.
- R2: 활성 상태. private Standard bucket `moneysnap-media-dev`, `moneysnap-media-prod`를 APAC에 생성했다.
- 원격 검증: 두 bucket 모두 임시 객체 PUT/GET, SHA-256 비교, DELETE를 통과했고 최종 `0 objects / 0 B`다.
- public surface: `r2.dev`, custom domain, CORS, Data Catalog 모두 비활성 상태다.
- API DNS: `moneysnap-server.ansandy.co.kr`가 사용자 관리 Nginx Proxy Manager를 거쳐 Ubuntu host `9090`으로 연결된다.
- monitoring DNS: `monitor.ansandy.co.kr`의 잘못된 origin IP를 수정했고 Grafana `/api/health` HTTP 200을 검증했다.
- named Tunnel: 현재 topology에서는 사용하지 않는다.
- Cloudflare Containers/Workers Paid: 비활성, 승인 전 금지
- application CI/CD: Docker image만 Ubuntu origin에 배포하며 DNS와 Nginx Proxy Manager는 별도 infrastructure lifecycle로 유지한다.

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

비밀값이 아닌 실제 resource ID와 endpoint는 `resources.yaml`이 소유한다. Spring Boot는 `R2_ENABLED=true`일 때만 AWS SDK v2로 `moneysnap-media-dev`에 연결한다. S3 credential은 Cloudflare Dashboard의 R2 API token에서 bucket `moneysnap-media-dev` Object Read & Write로 만들고 GitHub `server-development` secret에만 넣는다.

```text
gh secret set R2_ENABLED --env server-development
gh secret set R2_BUCKET --env server-development
gh secret set R2_ENDPOINT --env server-development
gh secret set R2_ACCESS_KEY_ID --env server-development
gh secret set R2_SECRET_ACCESS_KEY --env server-development
```

값은 `true`, `moneysnap-media-dev`, `https://6bcae71f04b38cc620c6d3b5bd68cd78.r2.cloudflarestorage.com`, Access Key, Secret이다. 대화·Git에 붙이지 않는다.

## 남은 생성 순서

1. Spring Boot media Adapter 작업에서 dev/prod bucket-scoped credential을 각각 만들고 저장소 밖 secret에 등록한다.
2. Adapter의 S3-compatible contract test로 PUT/HEAD/GET/DELETE와 presigned URL 만료·권한을 검증한다.
3. 공개 hostname에서 `/` smoke와 actuator 차단을 회귀 검증한다.
4. Ubuntu Docker 재부팅 복구와 Nginx Proxy Manager upstream을 정기 검증한다.
5. 공개 출시 전 현재 port-forward/NPM topology를 Cloudflare Tunnel 또는 managed origin으로 바꿀지 다시 승인받는다.

named Tunnel credential은 현재 발급하지 않는다. 도입 시 application release와 분리된 infrastructure 작업으로 다룬다.

GitHub Actions의 server deployment는 checksum이 검증된 Docker image와 runtime env만 교체한다. DNS, Nginx Proxy Manager, Prometheus/Grafana lifecycle은 변경하지 않는다.

공식 기준: [R2 pricing](https://developers.cloudflare.com/r2/pricing/), [R2 get started](https://developers.cloudflare.com/r2/get-started/), [Create a Tunnel API](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel-api/)

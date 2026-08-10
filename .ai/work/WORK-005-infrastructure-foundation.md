---
id: WORK-005
status: done
depends_on: [WORK-004]
owner: codex
---

# 개발·배포 인프라 기반 준비

## Intent

Money Snap의 애플리케이션 scaffold 전에 Neon 개발·운영 데이터베이스, Cloudflare 무료 범위와 Apple 개발자 계정 준비 경계를 실제로 설정하고 검증한다.

## In scope

- Neon Free의 개발·운영 프로젝트 분리 및 연결 방식 설정
- Testcontainers를 위한 PostgreSQL 기준 버전 정의
- Cloudflare 계정의 기존 zone, Tunnel, R2 상태 점검
- 무료 범위에서 안전하게 생성 가능한 Cloudflare 리소스 준비
- Apple Developer Program, App Store Connect, Xcode Cloud의 프로젝트 생성 전·후 준비 항목 구분
- 인프라 결정에 맞춘 ADR, 아키텍처, 기술 계획과 `AGENTS.md` 동기화

## Out of scope

- Spring Boot 또는 iOS 애플리케이션 scaffold와 기능 코드
- GitHub Actions, Xcode Cloud workflow와 자동 배포 구현
- Cloudflare Containers 또는 다른 유료 플랜 활성화
- 도메인 구매, public App Store 배포와 TestFlight 업로드
- 실제 production schema 또는 사용자 데이터 생성

## Acceptance criteria

- [x] Neon 개발·운영 환경이 서로 분리되고 Spring Boot가 사용할 연결 계약이 비밀값 없이 문서화된다.
- [x] Neon 연결 문자열이 Git 추적 대상에서 제외된다.
- [x] Cloudflare 로그인 후 기존 R2/Tunnel/zone을 조회하고 승인된 리소스를 생성한다.
- [x] Cloudflare 무료 범위·승인 경계를 벗어나는 변경을 하지 않는다.
- [x] Apple 개발자 계정에서 지금 준비할 항목과 iOS project 생성 후 설정할 항목이 구분된다.
- [x] 기준 문서와 `AGENTS.md`가 최신 인프라 결정 및 실제로 검증한 명령과 일치한다.

## Test seam

- Neon 연결·권한, Git ignore와 외부 리소스 조회 결과를 결정론적으로 검증한다.

## Verification

```text
git check-ignore infra/neon/.env.development.local infra/neon/.env.production.local
npx --yes wrangler@latest r2 bucket info moneysnap-media-dev
npx --yes wrangler@latest r2 bucket info moneysnap-media-prod
git diff --check
```

## Evidence

- 실행 명령: Neon organization/project 조회 후 `moneysnap-dev`와 `moneysnap-prod`를 생성하고 각 main branch에 `moneysnap_app` 역할·기본 권한을 설정했다.
- 결과: Neon 조직은 Free, 두 project는 PostgreSQL 18이다. dev는 `lucky-dew-23275491` / AWS us-east-1, prod는 `wandering-cell-45888626` / AWS us-west-2다.
- 실행 명령: dev/prod에서 role privilege 조회와 SCRAM verifier 대조를 실행했다.
- 결과: 두 역할 모두 `CONNECT=true`, schema `USAGE=true`, `CREATE=false`, admin role `false`이고 gitignored local secret과 SCRAM verifier가 일치했다.
- 실행 명령: `git check-ignore -v infra/neon/.env.development.local infra/neon/.env.production.local`, credential pattern scan, 필수 경로 검사, `git diff --check`.
- 결과: 두 secret file은 ignore되고 untracked 목록에 나타나지 않으며 credential pattern이 기준/예제 파일에서 검출되지 않았다. 필수 경로와 diff 검사가 통과했다.
- 실행 명령: 처음 만든 Compose PostgreSQL에 대해 PostgreSQL 18.4 SQL/health/loopback bind를 확인한 뒤 사용자 최신 결정에 따라 `docker compose ... down -v`, image 삭제와 Docker Desktop 중지를 실행했다.
- 결과: `moneysnap-postgres` container, `moneysnap-postgres-data` volume, 전용 network, `postgres:18-alpine` image와 `infra/local` 구성을 제거했다.
- 실행 명령: `npx --yes wrangler@latest login`, `whoami`, Cloudflare API와 Dashboard의 zone/R2/Tunnel 조회.
- 결과: Wrangler OAuth는 account ID `6bcae71f04b38cc620c6d3b5bd68cd78`에 연결됐다. active zone `ansandy.co.kr`가 있고 기존 Tunnel은 없었다. 기존 다른 R2 bucket과 token은 변경하지 않았다.
- 실행 명령: `npx --yes wrangler@latest r2 bucket create moneysnap-media-{dev,prod} --location APAC`, bucket info와 Dashboard settings 확인.
- 결과: 두 private R2 Standard bucket이 APAC에 생성됐다. `r2.dev`, custom domain, CORS, Data Catalog는 활성화하지 않았고 Workers Paid/Containers도 활성화하지 않았다.
- 실행 명령: 두 bucket의 `_infrastructure/smoke-check.txt`에 `r2 object put/get/delete --remote`, 내려받은 파일 SHA-256 비교, 삭제 후 `r2 bucket info`.
- 결과: dev/prod 원격 PUT/GET/DELETE가 성공하고 원본·다운로드 SHA-256 `47A7068F9E3CB43175728E9FF444F004ADA647D62C85722800A4A1D99A91F482`가 일치했다. 최종 상태는 각각 `object_count: 0`, `bucket_size: 0 B`다. 최초 `--remote` 없는 실행은 로컬 에뮬레이터였으므로 증거에서 제외하고 로컬 상태를 제거했다.
- 리뷰: R2 S3 credential은 Spring Boot media Adapter 생성 시 dev/prod bucket별 최소 권한으로 발급한다. named Tunnel과 DNS route는 연결할 health port와 hostname이 생기는 backend scaffold 이후에 생성한다. Apple App ID와 App Store Connect record는 최종 Bundle ID 확정 후 생성한다.

## Agent rules impact

- 영향 여부: yes
- 근거: PostgreSQL 개발·배포 위치, 외부 인프라 승인 경계와 실제 검증 명령이 바뀐다.
- 처리 결과: 기준 문서와 `AGENTS.md` 갱신 완료

## Code Review Graph

- 코드 변경 여부: no
- graph action: skipped
- base: `HEAD`
- risk: medium
- findings와 처리 결과: 인프라 구성·문서 작업이며 파싱 가능한 애플리케이션 소스는 생성하지 않는다. 최초 애플리케이션 scaffold 작업에서 full build한다.

## Decisions and risks

- 사용자 결정: 로컬 개발도 Neon을 기본으로 사용하고 dev/prod를 분리한다.
- 사용자 결정: 상시 Docker Compose PostgreSQL은 무거우므로 사용하지 않는다.
- 결정: 자동 테스트의 DB만 Testcontainers PostgreSQL로 일회성 격리한다.
- 위험: 무료 플랜 한도는 hard cost cap이 아니므로 리소스 생성 전 현재 조건과 계정 상태를 확인한다.
- 위험: Xcode, Simulator, signing과 App Store Connect 연결은 macOS/Xcode 및 실제 Bundle ID가 필요하다.
- 다음 단계 게이트: Apple App ID 생성 전 최종 Bundle ID, backend Tunnel 생성 전 health port와 hostname을 확정한다.

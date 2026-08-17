# 프로젝트: Money Snap

## AI 환경
- AI 작업 시작점: `.ai/README.md`
- 공용 프로젝트 용어: `CONTEXT.md`
- 작업·개선 그래프: `.ai/GRAPHS.md`
- 기획, 구현, 리뷰, 문서, 릴리스 루프: `.ai/LOOPS.md`
- AI 환경 구성과 이식 방법: `docs/AI_ENVIRONMENT.md`
- 프로젝트 로컬 스킬: `.agents/skills/`
- 횡단 단순성 게이트: Codex `ponytail:ponytail` 플러그인 (`plugin://ponytail@ponytail`)
- CRITICAL: 기능 작업 중 편의를 위해 제품 범위, Acceptance Criteria, 테스트, 보안 규칙을 완화하지 말 것
- CRITICAL: 하네스와 고정 앵커 변경은 기능 작업과 분리하고 사용자의 명시적 승인을 받을 것
- CRITICAL: 외부 시스템 변경, 배포, 삭제, 비용 발생 작업은 실행 전에 승인 경계를 확인할 것

## 현재 프로젝트 단계
- 현재 단계는 **개인 Snap, 그룹·초대·공유, visible/hidden Today, archive, My summary, 사진 grant/upload/complete/abort/cleanup/tombstone, iOS JPEG 정규화와 앨범 최대 3장 순차 기록이 Windows에서 구현된 상태**다. R2 Adapter는 `R2_ENABLED=true`와 bucket-scoped secret이 있을 때만 켜진다. development CD SSH, 실제 Apple device 설치와 macOS 393x852 visual은 아직 수행하지 않는다.
- 제품 방향, iOS 전용 MVP 범위, 서비스 정책, 핵심 사용자 흐름, Figma 화면 기준과 UI 원칙은 기준 문서에 정리되어 있다.
- SwiftUI + Spring Boot + PostgreSQL + Cloudflare DNS/R2 + Ubuntu Docker/Nginx Proxy Manager 기준 아키텍처는 `docs/ADR.md`와 `docs/ARCHITECTURE.md`에 확정되어 있다.
- `server/` Spring Boot scaffold와 `ios/` SwiftUI Xcode project가 있다. 서버는 local과 GitHub-hosted CI에서 test·bootJar를 통과했고 iOS는 Windows 정적 검증과 GitHub macOS native test·393x852 visual artifact 생성을 통과했다.
- 첫 기능 슬라이스 `WORK-010`의 Today Snap 읽기 도메인과 Figma Home `9:2` 화면이 완료됐다. 서버·iOS 테스트와 393x852 시각 회귀 임계값(MAE 0.05, 불일치 픽셀 비율 0.43)을 통과했다.
- repository는 public이고 draft PR #1이 remote CI 기준점이다. `server-development` environment는 `main` 전용 branch policy와 Ubuntu SSH·Neon secret 11개, Apple runtime secret 6개 계약을 보유하며 Secret Scanning과 Push Protection이 활성화되어 있다.
- Neon Free에 `moneysnap-dev`와 `moneysnap-prod`가 생성되어 있다. 개발·운영 DB를 공유하지 않는다.
- Cloudflare R2 Standard private bucket `moneysnap-media-dev`, `moneysnap-media-prod`가 APAC에 생성되어 있고 원격 PUT/GET/DELETE 검증을 통과했다. public access, CORS, Data Catalog는 비활성 상태다.
- development Spring Boot는 개발자 소유 Ubuntu Docker에서 `moneysnap-server`로 실행되며 private host `192.168.1.102:9090`, external network `main`, container management `9091` 계약을 사용한다. `moneysnap-server.ansandy.co.kr`은 Cloudflare DNS와 기존 Nginx Proxy Manager를 거쳐 `/` 200, public actuator 403을 반환한다.
- 기존 Prometheus는 host publish `127.0.0.1:9092`와 container `9090`을 사용하며 `moneysnap-server:9091` target을 `up=1`로 수집한다. Grafana `monitor.ansandy.co.kr/api/health`는 200이다.
- 서버의 Sign in with Apple 전체 경계와 iOS AuthenticationServices·Keychain 지속 session, 로그아웃·재인증 탈퇴 UI가 완료됐다. GitHub-hosted Xcode 16.4 Simulator에서 Swift Testing 61건·XCUITest 2건과 build-once Home/My 393x852 visual evidence가 통과했다. 실제 Apple credential 연동은 explicit App ID와 key activation이 필요하다.
- `WORK-019`에서 금액·`localDay`, private 사진 quota, 그룹·초대·불변 공개 설정, 저장 후 단일-group 공유와 profile fallback 정책을 2026-08-13 승인 기준으로 확정했다. Stage 3·6·7·8은 해당 runtime AC를 각 기능 테스트로 검증한다.
- 작업별 실시간 상태와 의존성은 `AGENTS.md`가 아니라 `.ai/work/`가 소유한다.

## 제품 기준 문서
- 제품 방향과 MVP 포함/제외 범위: `docs/PRD.md`
- 기록, 공유, 공개 정책: `docs/SERVICE_POLICY.md`
- 핵심 사용자 흐름: `docs/USER_FLOW.md`
- 화면 구조: `docs/SCREEN_STRUCTURE.md`
- UI와 인터랙션 규칙: `docs/UI_GUIDE.md`
- 구현 구조와 데이터/API 경계: `docs/ARCHITECTURE.md`
- 확정된 기술 결정과 근거: `docs/ADR.md`
- Spring Boot·Cloudflare·Windows/Xcode 공식 조사: `docs/SPRING_CLOUDFLARE_RESEARCH.md`
- 현재 단계별 기술 계획: `docs/TECHNICAL_DESIGN_PROPOSAL.md`
- CI/CD 공식 조사와 실제 운영 계약: `docs/CI_CD_RESEARCH.md`, `docs/CI_CD.md`
- 실제 인프라 상태와 비밀값 계약: `infra/README.md`, `infra/neon/README.md`, `infra/cloudflare/README.md`, `infra/apple/README.md`

## 범위 관리
- CRITICAL: 설계나 구현 전에 `docs/PRD.md`의 MVP 포함/제외 범위를 확인할 것
- CRITICAL: 문서와 사용자의 최신 명시적 결정이 충돌하면 최신 결정을 우선하고, 작업 전에 기준 문서를 갱신할 것
- CRITICAL: 기준 문서에 없는 기능을 추론하여 MVP 범위에 추가하지 말 것
- 세부 문서가 `docs/PRD.md`와 충돌하면 작업을 진행하기 전에 문서를 일치시킬 것

## 기술 스택
- MVP 플랫폼: native iOS 전용, iOS 17+, Swift 6, SwiftUI, Swift Concurrency, Observation, AuthenticationServices, Keychain, PhotosUI, URLSession, SpriteKit
- API: Java 21 LTS, Spring Boot 4.1.0, Gradle 9.5.1, REST/JSON, OpenAPI 3.1
- API contract gate: test-only Swagger Parser `2.1.45`, NetworkNT JSON Schema Validator `3.0.6`, canonical `contracts/examples/v1/**`; 기본 server `test`와 iOS native test가 동일 fixture를 검증
- 데이터: Neon PostgreSQL 18, dev/prod project 분리, Flyway, Spring Data JPA
- DB 테스트: 테스트 실행 중에만 PostgreSQL 18 Testcontainers 사용
- 사진: private Cloudflare R2 Standard, AWS SDK for Java v2, short-lived presigned URL
- 무료 폐쇄형 배포: Cloudflare DNS → Nginx Proxy Manager → 개발자 소유 Ubuntu Docker의 stateless Spring Boot origin
- 서버 CI/CD: GitHub-hosted Ubuntu test/package → pinned SSH Ubuntu Docker development deploy
- iOS 검증·배포: path-scoped GitHub-hosted `macos-15`의 Xcode 16.4·iPhone 16·iOS 18.5 unit+UI test/393x852 visual evidence → 성공한 `main` iOS CI 이후 같은 runner의 `ios-testflight` environment가 archive/TestFlight 업로드
- CRITICAL: 표준 Workers는 Spring Boot runtime이 아니며 D1은 JPA datasource로 사용하지 않는다.
- CRITICAL: Cloudflare Containers는 무료가 아니므로 월 최소 5 USD와 초과 과금 승인 전에는 활성화하거나 배포하지 않는다.
- CRITICAL: 상시 Docker Compose PostgreSQL을 추가하지 않는다. 개발은 Neon dev, 운영은 Neon prod를 사용하며 테스트만 일회성 Testcontainers로 격리한다.

## 아키텍처 규칙
- 하나의 iOS app, 하나의 Spring Boot modular monolith, 하나의 PostgreSQL로 시작한다.
- backend는 package-by-feature `identity`, `snap`, `group`, `media` 경계를 따른다. microservice, Kafka, Redis, GraphQL은 MVP에서 도입하지 않는다.
- MVP identity provider는 Sign in with Apple 하나다. access token은 15분, rotating refresh session은 180일 inactivity window를 사용하고 iOS Keychain에 저장한다.
- 로그아웃은 현재 device session만 폐기한다. 계정 탈퇴는 재인증 후 모든 session·사용자 데이터를 삭제하고 Apple token을 revoke한다.
- 점심·저녁 리마인더를 포함한 로컬 알림과 APNs 원격 알림은 MVP에서 제외한다.
- Snap은 항상 개인 기록으로 먼저 저장하며 group 공유를 같은 command에 넣지 않는다.
- Apple 인증·event request는 future field를 허용하지만 Snap·group·share 상태 변경 command는 선언되지 않은 field를 국소적으로 거부한다. `clientMutationId`는 actor 범위의 1~128자 nonblank opaque key이며 commit-unknown retry에서 바꾸지 않는다.
- Snap 금액은 `1...999,999,999 KRW` 정수다. `localDay`는 server `Clock`과 제출된 tzdb region `ZoneId` 또는 `UTC`로 current day·직전 day만 허용하고 저장 후 바꾸지 않으며 numeric offset·short alias는 거부한다.
- Stage 3은 사진 없는 category+amount 개인 Snap을 먼저 완성하고 Stage 6에서 camera·PhotosUI·private R2를 연결한다. Snap당 active image는 최대 1개이며 JPEG 최대 변 `1600px`, `2,097,152 bytes`, EXIF 제거를 요구한다.
- 사진 grant는 최근 24시간 completed+nonexpired pending 20건과 active+pending `7,000,000,000 bytes` storage guardrail을 원자적으로 적용한다. direct PUT이 exact length·type·checksum을 강제하지 못하면 unrestricted grant 대신 backend bounded stream을 사용한다.
- 그룹은 owner 한 명과 member, owner 포함 최대 20명이고 이름은 trim 후 1~30 grapheme cluster다. amount visibility는 생성 시 고정하며 초대는 최소 128-bit entropy·hash-only·168시간·group당 active 하나다.
- 그룹 삭제·member 탈퇴·제거는 share 관계만 삭제하고 개인 Snap을 보존한다. owner 계정 탈퇴는 owned group/share를 삭제한 뒤 account cascade가 owner 개인 데이터를 삭제한다.
- 공유는 durable 개인 Snap의 Home action에서 한 Snap→한 group으로만 실행한다. skip·취소·실패는 개인 save를 rollback하지 않고, 사진 없는 공유·대표 Snap은 category별 고정 placeholder와 최신 `sharedAt`을 사용한다.
- 금액 비공개 group response에는 금액과 금액 기반 크기·정렬 필드를 포함하지 않는다. client-side hide로 구현하지 않는다.
- Apple 이름이 첫 로그인에서 유효하게 제공되면 display name으로 저장하고, 없으면 `MoneySnap 사용자`를 사용한다. 이름 편집과 profile 사진은 MVP에서 제외하며 기본 avatar는 첫 grapheme 또는 MoneySnap mark다.
- 사진 bucket은 private다. iOS에 R2 credential이나 permanent object URL을 넣지 않고 backend 권한 검사 후 짧은 PUT/GET grant만 사용한다.
- complete된 미연결 media는 `completedAt`부터 24시간 동안 같은 사용자의 draft 복구를 위해 보존하고 explicit abort 또는 경계 이후에만 cleanup한다. 계정 탈퇴 전에는 media object key를 account-independent cleanup row로 옮겨 R2 orphan과 byte 회계 누락을 막는다.
- 기존 Cloudflare account-wide R2 token을 재사용하지 않는다. Spring Boot media Adapter를 만들 때 dev/prod bucket별 최소 권한 credential을 생성해 저장소 밖 secret으로 주입한다.
- Figma frame node와 393x852 screenshot을 화면 구현의 source of truth로 사용하며 macOS snapshot diff 없이 UI 작업을 완료 처리하지 않는다.
- Windows에서는 source/project 파일을 작성할 수 있지만 Xcode, Simulator, signing, archive와 pixel verification은 macOS lane에서 수행한다.
- 무료 Tunnel topology는 폐쇄형 TestFlight만 허용한다. 공개 출시와 exit 기준은 `docs/ARCHITECTURE.md`를 따른다.
- Spring runtime은 Neon pooled endpoint와 `moneysnap_app`을 사용하고, Flyway·dump/restore만 direct endpoint와 owner credential을 사용한다.
- 서버 설정의 `NEON_RUNTIME_DATABASE_*`와 `NEON_MIGRATION_DATABASE_*`는 서로 독립된 필수 변수다. 테스트는 두 auto-configuration을 끄거나 Testcontainers를 사용하며 실제 Neon에 접속하지 않는다.
- 인증 기능 전까지 `/actuator/health`만 익명 접근을 허용하고 나머지 route는 기본 거부한다. public API hostname에서는 actuator path 자체를 노출하지 않는다.
- 최종 Bundle ID는 `com.ansandy.moneysnap`이다. Apple explicit App ID와 App Store Connect app record 생성은 별도 Apple activation 작업에서 수행하며 private key·certificate·2FA code를 저장소에 넣지 않는다.
- GitHub workflow action은 full commit SHA로 고정하고 Dependabot PR로 갱신한다. workflow 기본 권한은 `contents: read`다.
- `main` branch는 PR, linear history와 conversation resolution을 요구하고 force-push·delete를 금지한다. path-scoped CI를 required check로 지정하면 관련 없는 PR이 pending될 수 있으므로 항상 실행되는 gate를 설계하기 전에는 required status check를 추가하지 않는다.
- public repository의 pull request CI와 server/iOS test job에는 Neon, SSH, R2, Tunnel, Apple runtime, App Store Connect 배포 secret을 주입하지 않는다. development CD는 성공한 `main` push의 checksum 검증 Docker image와 `server-development` environment만 사용한다. iOS TestFlight CD는 `ios-testflight` environment만 사용한다.
- `deploy-development` job만 `server-development`의 Neon·SSH·Apple runtime secret과, `R2_ENABLED=true`일 때 R2 bucket-scoped secret을 Ubuntu `/opt/moneysnap/runtime.env`에 mode `600`으로 쓴다. `/opt/moneysnap/.env`는 Compose interpolation stub만 둔다. Tunnel secret은 이 CD에 넣지 않는다.
- application CD는 Cloudflare DNS, Nginx Proxy Manager, Prometheus/Grafana 설정을 생성·변경·재시작하지 않는다. infrastructure lifecycle은 별도 승인 작업이 소유한다.
- public API는 application `/` smoke만 허용하고 management `9091`과 actuator는 Docker `main` network 안에만 둔다.
- SSH host identity는 pinned known_hosts로 검증하고 runtime secret file은 Ubuntu `/opt/moneysnap/runtime.env` mode `600`으로 유지한다. 대화·로그에 노출된 key는 회전하며 장기적으로 최소 권한 deploy account를 사용한다.
- 자동 rollback은 JAR과 동일 release secret 복원까지만 수행한다. DB down migration은 자동화하지 않고 schema 변경은 이전 JAR과 호환되는 expand-first AC를 요구한다.

## 개발 프로세스
- CRITICAL: 새 기능 구현 시 반드시 테스트를 먼저 작성하고, 테스트가 통과하는 구현을 작성할 것 (TDD)
- 작업 시작 전 `.ai/templates/work-item.md` 형식으로 Intent, 범위, AC, 검증 방법을 고정할 것
- 모든 작업 항목에 `Agent rules impact`를 작성해 `AGENTS.md` 영향 여부, 근거, 처리 결과를 남길 것
- 완료 전 실제 검증 명령을 실행하고 결과를 Evidence로 남길 것
- 커밋 메시지는 conventional commits 형식을 따를 것 (feat:, fix:, docs:, refactor:)

## AGENTS.md 최신성 계약
- `AGENTS.md`는 모든 에이전트가 먼저 읽는 프로젝트 실행 계약이며, 단기 진행 로그나 세부 제품 명세를 복제하지 않는다.
- 다음 사실이 바뀌면 같은 작업 안에서 `AGENTS.md` 영향 여부를 반드시 검토한다: 기준 문서 경로, 제품·보안 불변 규칙, 승인 경계, 기술 스택, 아키텍처 원칙, 개발 절차, 실제 검증 명령.
- 영향이 있으면 기준 문서를 먼저 갱신한 뒤 `AGENTS.md`의 요약·링크·명령을 동기화한다. 영향이 없으면 작업 항목에 그 근거를 남긴다.
- 문서 동기화 루프에서 기준 문서와 `AGENTS.md`를 비교하고, 완료 전에 결과를 작업 항목 Evidence에 기록한다.
- 자동 훅은 이 수동 검사가 반복적으로 유효하고 결정론적임이 확인된 뒤, 기능 작업과 분리된 하네스 개선 작업 및 사용자 승인으로만 추가한다.
- `AGENTS.md` 자체, `.ai/harness.yaml`의 고정 앵커 또는 승인 경계를 바꾸는 일은 사용자의 명시적 요청 없이 수행하지 않는다.

## Code Review Graph
- 애플리케이션 소스 또는 테스트 코드가 바뀌면 하나의 의미 있는 변경 묶음이 끝난 뒤 `code-review-graph`를 증분 update한다. 문서만 바뀐 작업은 생략 사유를 작업 항목에 남긴다.
- 코드 리뷰, 인수인계, 병합·릴리스 준비 전에는 그래프 최신성을 다시 확인한다.
- 항상 `get_minimal_context_tool`로 시작한다. 그래프가 없거나 손상됐거나, 파싱 가능한 소스가 있는데도 인덱스가 비어 있으면 `build_or_update_graph_tool(full_rebuild=true)`로 먼저 build한다.
- 유효한 그래프가 있으면 `build_or_update_graph_tool(full_rebuild=false, base=<고정 리뷰 기준점>)`로 증분 update한다. full rebuild를 관성적으로 반복하지 않는다.
- update 후 `get_minimal_context_tool`을 다시 호출하고, 위험도가 낮으면 `detect_changes_tool(detail_level="minimal")`, 중간·높음이면 `detail_level="standard"`로 영향·흐름·테스트 공백을 확인한다.
- actionable finding은 현재 작업의 범위와 AC 안에서 TDD로 수정한다. 수정 후 테스트를 실행하고 그래프를 다시 증분 update한 뒤 finding을 재검토한다.
- 그래프 상태, build/update 종류, 기준점, 위험도, finding 처리 결과를 작업 항목의 `Code Review Graph`와 Evidence에 기록한다.
- `.code-review-graph/`는 런타임 로컬 상태이며 커밋하지 않는다. 상시 `watch`나 자동 훅은 수동 주기가 검증된 뒤 별도 승인 작업으로만 도입한다.
- 그래프 결과는 보조 증거다. 테스트, 원 명세, 제품 범위, 보안 규칙이나 사용자 승인을 대체하지 않는다.

## 명령어
- CRITICAL: 존재하지 않거나 실행하지 않은 명령을 검증 증거로 기록하지 말 것
- 서버 전체 테스트: `cd server; .\gradlew.bat test --no-daemon --console=plain`
- OpenAPI semantic contract 테스트: `cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.contract.OpenApiContractTests" --no-daemon --console=plain`
- 서버 production JAR 생성: `cd server; .\gradlew.bat bootJar --no-daemon --console=plain`
- Windows iOS project 정적 검증: `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1`
- Windows iOS visual baseline 계약 검증: `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1`
- CI/CD repository 계약 검증: `powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1`
- Ubuntu Docker deployment 동작 검증: `bash server/scripts/test-docker-deployment.sh`
- Ubuntu Compose 계약 검증: `MONEYSNAP_IMAGE=moneysnap-server:validation MONEYSNAP_ENV_FILE=/path/to/runtime.env docker compose -f infra/ubuntu/compose.yaml config --quiet`
- macOS native iOS 검증: `bash ios/scripts/test.sh` (unit+non-parallel UI test, GitHub-hosted Xcode 16.4·iPhone 16·iOS 18.5)
- macOS visual evidence 생성: `bash ios/scripts/capture-visual-baseline.sh` (앱을 한 번 build/install하고 manifest 순서의 모든 393x852 app/reference/overlay/diff/report를 생성한 뒤 실패를 집계)
- 현재 AI 환경 문서 변경의 기본 검증 명령: `git diff --check`
- 현재 필수 AI 환경 경로 검증 명령: `$required = @('AGENTS.md','CONTEXT.md','.ai/README.md','.ai/harness.yaml','.ai/GRAPHS.md','.ai/LOOPS.md','.ai/templates/work-item.md','docs/AI_ENVIRONMENT.md'); $missing = $required | Where-Object { -not (Test-Path -LiteralPath $_) }; if ($missing) { $missing; exit 1 }`

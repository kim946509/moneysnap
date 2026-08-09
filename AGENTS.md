# 프로젝트: Money Snap

## AI 환경
- AI 작업 시작점: `.ai/README.md`
- 공용 프로젝트 용어: `CONTEXT.md`
- 작업·개선 그래프: `.ai/GRAPHS.md`
- 기획, 구현, 리뷰, 문서, 릴리스 루프: `.ai/LOOPS.md`
- AI 환경 구성과 이식 방법: `docs/AI_ENVIRONMENT.md`
- 프로젝트 로컬 스킬: `.agents/skills/`
- CRITICAL: 기능 작업 중 편의를 위해 제품 범위, Acceptance Criteria, 테스트, 보안 규칙을 완화하지 말 것
- CRITICAL: 하네스와 고정 앵커 변경은 기능 작업과 분리하고 사용자의 명시적 승인을 받을 것
- CRITICAL: 외부 시스템 변경, 배포, 삭제, 비용 발생 작업은 실행 전에 승인 경계를 확인할 것

## 현재 프로젝트 단계
- 현재 단계는 **public repository remote CI와 iOS visual baseline 활성화, development CD·Apple activation 전**이다.
- 제품 방향, iOS 전용 MVP 범위, 서비스 정책, 핵심 사용자 흐름, Figma 화면 기준과 UI 원칙은 기준 문서에 정리되어 있다.
- SwiftUI + Spring Boot + PostgreSQL + Cloudflare Tunnel/R2 기준 아키텍처는 `docs/ADR.md`와 `docs/ARCHITECTURE.md`에 확정되어 있다.
- `server/` Spring Boot scaffold와 `ios/` SwiftUI Xcode project가 있다. 서버는 local과 GitHub-hosted CI에서 test·bootJar를 통과했고 iOS는 Windows 정적 검증과 GitHub macOS native test·393x852 visual artifact 생성을 통과했다.
- repository는 public이고 draft PR #1이 remote CI 기준점이다. `server-development` environment는 `main` 전용 branch policy가 있지만 secret은 비어 있고 self-hosted deployment와 TestFlight는 미활성 상태다.
- Neon Free에 `moneysnap-dev`와 `moneysnap-prod`가 생성되어 있다. 개발·운영 DB를 공유하지 않는다.
- Cloudflare R2 Standard private bucket `moneysnap-media-dev`, `moneysnap-media-prod`가 APAC에 생성되어 있고 원격 PUT/GET/DELETE 검증을 통과했다. public access, CORS, Data Catalog는 비활성 상태다.
- Cloudflare named Tunnel과 DNS route는 아직 만들지 않았다. Spring Boot origin은 `127.0.0.1:8080`을 기본으로 하며 hostname과 외부 노출 작업 AC를 확정한 뒤 dev Tunnel부터 생성한다.
- 다음 기술 게이트는 Windows runner·`server-development` secret activation, Apple explicit App ID와 Xcode Cloud 첫 workflow다. 인증 정책·사진 quota를 결정한 뒤 첫 개인 Snap vertical slice를 시작한다.
- 그룹 생성·초대, 그룹 공개 설정 변경, 저장 후 공유 진입처럼 미결정인 제품 정책은 관련 기능의 작업 항목을 `ready`로 바꾸기 전에 확정한다.
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
- MVP 플랫폼: native iOS 전용, iOS 17+, Swift 6, SwiftUI, Swift Concurrency, Observation, PhotosUI, URLSession, SpriteKit
- API: Java 21 LTS, Spring Boot 4.1.0, Gradle 9.5.1, REST/JSON, OpenAPI 3.1
- 데이터: Neon PostgreSQL 18, dev/prod project 분리, Flyway, Spring Data JPA
- DB 테스트: 테스트 실행 중에만 PostgreSQL 18 Testcontainers 사용
- 사진: private Cloudflare R2 Standard, AWS SDK for Java v2, short-lived presigned URL
- 무료 폐쇄형 배포: Cloudflare named Tunnel 뒤의 stateless Spring Boot origin
- 서버 CI/CD: GitHub-hosted Ubuntu test/package → 전용 Windows self-hosted runner development deploy
- iOS 검증·배포: path-scoped GitHub-hosted `macos-15`의 Xcode 16.4·iPhone 16·iOS 18.5 test/393x852 visual evidence → Apple Developer Program에 포함된 Xcode Cloud archive/TestFlight
- CRITICAL: 표준 Workers는 Spring Boot runtime이 아니며 D1은 JPA datasource로 사용하지 않는다.
- CRITICAL: Cloudflare Containers는 무료가 아니므로 월 최소 5 USD와 초과 과금 승인 전에는 활성화하거나 배포하지 않는다.
- CRITICAL: 상시 Docker Compose PostgreSQL을 추가하지 않는다. 개발은 Neon dev, 운영은 Neon prod를 사용하며 테스트만 일회성 Testcontainers로 격리한다.

## 아키텍처 규칙
- 하나의 iOS app, 하나의 Spring Boot modular monolith, 하나의 PostgreSQL로 시작한다.
- backend는 package-by-feature `identity`, `snap`, `group`, `media` 경계를 따른다. microservice, Kafka, Redis, GraphQL은 MVP에서 도입하지 않는다.
- Snap은 항상 개인 기록으로 먼저 저장하며 group 공유를 같은 command에 넣지 않는다.
- 금액 비공개 group response에는 금액과 금액 기반 크기·정렬 필드를 포함하지 않는다. client-side hide로 구현하지 않는다.
- 사진 bucket은 private다. iOS에 R2 credential이나 permanent object URL을 넣지 않고 backend 권한 검사 후 짧은 PUT/GET grant만 사용한다.
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
- secret이 있는 persistent Windows runner에서는 PR·임의 branch code를 실행하지 않는다. development CD는 성공한 `main` push artifact와 `[self-hosted, Windows, X64, moneysnap-dev]` label을 모두 요구한다.
- GitHub-hosted CI에는 Neon/R2/Tunnel/Apple secret을 주입하지 않는다. server environment secret은 deployment step과 Windows ACL secret files에만 전달한다.
- application CD는 Cloudflare Tunnel/DNS/token이나 `cloudflared` service를 생성·재시작하지 않는다. infrastructure lifecycle은 별도 승인 작업이 소유한다.
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
- 서버 production JAR 생성: `cd server; .\gradlew.bat bootJar --no-daemon --console=plain`
- Windows iOS project 정적 검증: `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1`
- Windows iOS visual baseline 계약 검증: `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1`
- CI/CD repository 계약 검증: `powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1`
- Windows deployment 동작 검증: `powershell -ExecutionPolicy Bypass -File server\scripts\test-deployment-support.ps1`
- macOS native iOS 검증: `bash ios/scripts/test.sh` (GitHub-hosted Xcode 16.4·iPhone 16·iOS 18.5에서 통과)
- macOS visual evidence 생성: `bash ios/scripts/capture-visual-baseline.sh` (393x852 app/reference/overlay/diff/report 생성 검증 완료)
- 현재 AI 환경 문서 변경의 기본 검증 명령: `git diff --check`
- 현재 필수 AI 환경 경로 검증 명령: `$required = @('AGENTS.md','CONTEXT.md','.ai/README.md','.ai/harness.yaml','.ai/GRAPHS.md','.ai/LOOPS.md','.ai/templates/work-item.md','docs/AI_ENVIRONMENT.md'); $missing = $required | Where-Object { -not (Test-Path -LiteralPath $_) }; if ($missing) { $missing; exit 1 }`

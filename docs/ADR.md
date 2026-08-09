# Architecture Decision Records

> 기준일: 2026-08-08

## 철학

Money Snap은 iPhone의 기록 경험과 개인정보 보호를 우선하는 작은 MVP다. 제품 정책과 Figma 정합성은 인프라 편의보다 우선하며, backend는 한 번에 배포하는 modular monolith로 시작한다. 무료 운영은 목표이지만 보안·테스트·Acceptance Criteria를 낮추지 않는다.

## 결정 상태

| ADR | 상태 | 결정 |
|---|---|---|
| ADR-001 | accepted | MVP는 native iOS 전용 |
| ADR-002 | accepted | Spring Boot modular monolith와 PostgreSQL |
| ADR-003 | accepted | Cloudflare는 edge·Tunnel·R2에 사용하고 무료 폐쇄형 MVP부터 시작 |
| ADR-004 | accepted | Figma node와 screenshot diff를 시각적 기준으로 사용 |
| ADR-005 | accepted | Windows 개발과 macOS iOS 검증 lane 분리 |
| ADR-006 | rejected | D1을 Spring Boot 주 데이터베이스로 사용하지 않음 |
| ADR-007 | accepted | 개발·운영 PostgreSQL은 분리된 Neon Free 프로젝트 사용 |
| ADR-008 | accepted | 서버는 GitHub Actions CI/CD, iOS는 GitHub Simulator CI와 Xcode Cloud CD 사용 |
| ADR-009 | accepted | Bundle ID와 iOS visual verification toolchain 고정 |

## ADR-001: native iOS 전용 MVP

**결정**: MVP 클라이언트는 iOS 17 이상, Swift 6 language mode, SwiftUI, Swift Concurrency, Observation으로 작성한다. 사진 선택은 PhotosUI, API는 URLSession, 오늘의 소비 오브젝트 낙하·충돌은 SpriteKit을 SwiftUI 안에 포함해 구현한다. Android와 웹은 MVP에서 만들지 않는다.

**이유**: 사용자가 iOS 전용 MVP를 확정했고, 기존 Figma가 iPhone system chrome·SF Symbols·sheet·tab 감각을 전제로 한다. native 구현이 사진, safe area, 접근성, 물리 캔버스와 시각적 정합성을 가장 직접적으로 제어한다.

**트레이드오프**: Android·웹 코드 재사용을 포기한다. iOS build·Simulator·서명에는 macOS가 필요하다.

## ADR-002: Spring Boot modular monolith와 PostgreSQL

**결정**: backend는 Java 21 LTS와 현재 확정 시점의 Spring Boot 4.1 계열로 시작한다. Gradle, Spring Web, Spring Security, Validation, Spring Data JPA, Flyway, PostgreSQL을 사용한다. 배포 단위는 하나이며 package-by-feature로 `identity`, `snap`, `group`, `media` 경계를 둔다. API 경계는 versioned REST/JSON과 OpenAPI 3.1이다.

**이유**: 사용자가 Spring Boot를 확정했다. 개인 우선 기록, 수정·삭제 전파, 그룹 membership, 금액 공개 projection은 관계형 무결성과 서버 트랜잭션이 중요하다. Java 21은 무료·저사양 JVM host와 컨테이너에서 호환성이 넓은 LTS 기준이다.

**트레이드오프**: Workers-only 구조보다 메모리와 cold start가 크고 JVM origin 운영이 필요하다. microservice, Kafka, Redis, GraphQL, 실시간 socket과 완전한 offline sync는 MVP에서 도입하지 않는다.

## ADR-003: Cloudflare 무료 폐쇄형 MVP와 단계적 compute 이전

**결정**: 첫 폐쇄형 TestFlight MVP는 Cloudflare Free의 named Tunnel로 개발자 소유 origin의 Spring Boot를 노출하고, 사진은 private R2 Standard에 저장한다. API 앞에 별도 Worker gateway를 두지 않는다. Spring Boot process는 stateless OCI image/JAR 계약을 지켜 origin만 교체할 수 있게 한다.

공개 App Store 출시 전 또는 exit 기준 도달 시 origin을 재평가한다. Cloudflare에 Spring Boot를 직접 배포하기로 하면 Containers로 이동하되 Workers Paid의 월 최소 5 USD와 초과 과금을 별도 승인한다. 외부 무료 JVM host는 공식 무료 조건과 cold start를 실제 검증한 경우에만 Tunnel 대안으로 채택한다.

**이유**: 표준 Workers에는 JVM이 없고 Cloudflare Containers는 Spring Boot를 실행할 수 있지만 무료 티어가 없다. Tunnel은 compute를 제공하지 않지만 기존 host를 공개 포트 없이 Cloudflare edge에 연결할 수 있다. R2는 S3-compatible API, 월 10GB Standard storage, Class A 100만, Class B 1,000만, 인터넷 egress 무료 범위가 저사용자 사진 MVP에 적합하다.

**트레이드오프**: 무료 Tunnel 단계에는 SLA가 없고 host 전원·인터넷·patch·backup이 단일 장애점이다. R2 budget alert는 비용을 차단하지 않으므로 월 0원을 절대 보장하지 않는다. 서버가 업로드 grant를 제한하고 무료 범위 70%에서 신규 업로드를 정지하는 kill switch를 둔다. 공개 출시, DAU 20 초과, 30분 이상 장애, 주 2회 사용자 영향 장애 중 하나면 무료 origin을 종료한다.

## ADR-004: Figma source of truth와 visual regression

**결정**: [Money Snap - Product Design](https://www.figma.com/design/IDNeYlc3584NY9YhsyUQYE/Money-Snap---Product-Design?node-id=0-1&t=lW8FBJFfcXo3cHEC-1)을 시각적 source of truth로 사용한다. 화면 작업은 실제 frame node ID, 393x852 reference screenshot, 추출 asset과 token을 고정한 뒤 SwiftUI snapshot과 overlay/diff를 통과해야 완료된다. 첫 기준선은 홈 `9:2`이며 구현 전에는 차이를 report-only로 기록한다.

**이유**: 사용자는 Figma와 거의 동일한 결과를 요구한다. 화면 이름만 참조하면 디자인 변경과 구현 오차를 추적할 수 없지만 node ID와 고정 fixture는 차이를 반복 검증할 수 있다.

**트레이드오프**: macOS Simulator와 screenshot baseline 관리 비용이 생긴다. Figma의 React/Tailwind 출력은 production 코드로 사용하지 않으며 SwiftUI로 변환한다. asset URL이 만료되기 전에 원본을 저장소 asset catalog로 가져와야 한다.

## ADR-005: Windows authoring과 macOS verification 분리

**결정**: Windows는 Spring Boot 전체 개발, Swift·Xcode 프로젝트 파일 작성과 Git 작업에 사용한다. Xcode 실행, iOS SDK build, Simulator, SwiftUI preview, signing, archive, TestFlight/App Store upload, pixel verification은 macOS lane에서 수행한다. Apple Developer Program에 포함된 Xcode Cloud 월 25시간을 CI 기본 후보로 사용하되 첫 workflow와 interactive 조정에는 Mac/Xcode 접근이 필요하다.

**이유**: Apple이 배포하는 Xcode toolchain은 지원 macOS를 요구한다. 유료 Apple Developer 계정은 배포 권한과 Xcode Cloud quota를 제공하지만 Windows에 Xcode runtime을 제공하지 않는다.

**트레이드오프**: Mac 접근이 확보되기 전까지 iOS 결과를 완료로 판정할 수 없다. Xcode Cloud는 자동 build/test/archive에는 적합하지만 interactive pixel tuning을 대체하지 않는다.

## ADR-006: D1을 Spring Boot 주 DB에서 제외

**결정**: D1과 Hyperdrive를 MVP Spring Boot의 persistence 경로에서 사용하지 않는다. PostgreSQL을 사용한다.

**이유**: D1은 SQLite 기반 Workers binding/SQL API이며 외부 애플리케이션용 JDBC wire endpoint를 제공하지 않는다. 외부 접근에는 proxy Worker가 필요해 Spring Data JPA의 connection·transaction 의미와 맞지 않는다. Hyperdrive도 Workers가 외부 Postgres에 접근할 때 사용하는 binding이지 Spring Boot용 JDBC endpoint가 아니다.

**트레이드오프**: D1의 무료 5GB와 hard quota를 활용하지 못하고 PostgreSQL origin을 별도로 운영해야 한다. 대신 Flyway, JPA, Testcontainers와 관계형 트랜잭션을 직접 사용할 수 있다.

## ADR-007: Neon 개발·운영 PostgreSQL

**결정**: 기본 개발 DB는 Neon Free의 `moneysnap-dev`, 폐쇄형 TestFlight 운영 DB는 별도 `moneysnap-prod` 프로젝트를 사용한다. Spring runtime은 pooled endpoint와 최소 권한 `moneysnap_app` 역할을 사용하고, Flyway·dump·restore만 direct endpoint와 owner 역할을 사용한다. 상시 Docker Compose PostgreSQL은 두지 않으며 자동 테스트에서만 PostgreSQL 18 Testcontainers를 일회성으로 사용한다.

**이유**: 사용자가 PC마다 무거운 PostgreSQL container를 계속 실행하는 대신 로컬 개발부터 Neon을 쓰기로 확정했다. dev/prod project 분리는 개발 migration과 데이터가 운영에 섞이는 것을 막고, Neon Free의 scale-to-zero는 낮은 사용량에 맞는다. pooled/runtime과 direct/migration 자격 증명을 분리하면 owner credential의 노출 면적도 줄어든다.

**트레이드오프**: 인터넷이 없으면 통합 개발 DB를 사용할 수 없고, Free는 project당 storage 0.5GB와 월 100 CU-hour·5GB public transfer 한도 및 SLA 부재가 있다. 한도 도달 시 compute가 월말까지 중단될 수 있다. 생성 도구가 region 선택을 지원하지 않아 dev는 AWS us-east-1, prod는 AWS us-west-2에 생성됐으며 공개 출시 전 한국 사용자·origin 기준 latency와 data migration을 재평가한다.

## ADR-008: GitHub Actions와 Xcode Cloud CI/CD 분리

**결정**: Spring Boot의 test·JAR packaging은 GitHub-hosted Ubuntu, development origin 배포는 `[self-hosted, Windows, X64, moneysnap-dev]` 전용 runner에서 GitHub Actions로 수행한다. iOS pull request native test는 path-scoped GitHub-hosted `macos-15`에서 signing 없이 실행하고, archive·signing·internal TestFlight CD는 Xcode Cloud가 소유한다. Cloudflare Tunnel/DNS/token lifecycle은 application release workflow와 분리한다.

모든 GitHub Action reference는 전체 commit SHA로 고정하고 Dependabot이 갱신한다. workflow 기본 권한은 `contents: read`이며 persistent deployment runner는 `main` push의 검증된 artifact job만 실행한다. server secret은 deployment job과 Windows ACL secret files에만 존재하고 GitHub-hosted CI나 artifact에는 전달하지 않는다.

**이유**: 서버는 Windows origin에서 실행되므로 외부 SSH surface 없이 같은 host의 전용 runner가 local JAR을 교체하는 경로가 가장 작다. iOS는 Windows에서 검증할 수 없지만 GitHub macOS runner가 PR compile/test feedback을 제공하고, Apple-managed signing과 포함된 Xcode Cloud quota가 TestFlight credential surface를 줄인다. Tunnel과 app release를 분리하면 JAR rollback이 connector·DNS 상태를 건드리지 않는다.

**트레이드오프**: self-hosted runner와 Windows host는 persistent 공격·장애 영역이므로 PR code를 절대 실행하지 않고 repository 접근을 제한해야 한다. public repository의 standard GitHub-hosted Actions는 무료지만 persistent self-hosted runner의 공격면은 더 엄격하게 다뤄야 한다. Xcode Cloud 첫 workflow, Apple App record, Windows runner와 GitHub environment secret은 repository 파일만으로 활성화할 수 없어 외부 gate가 남는다. 자동 JAR rollback과 양방향 DB migration을 결합하지 않으며 schema는 expand-first 호환성을 별도 AC로 요구한다.

## ADR-009: Bundle ID와 iOS visual verification 기준선

**결정**: Money Snap의 최종 Bundle ID는 `com.ansandy.moneysnap`이다. GitHub iOS CI의 visual verification 기준선은 Xcode 16.4, iPhone 16, iOS 18.5, 393x852 points로 고정한다. Simulator UDID는 runner마다 달라지므로 device·runtime으로 찾고, app screenshot, Figma reference, overlay, diff와 수치 report를 artifact로 남긴다. iOS deployment target은 17 이상을 유지한다.

**이유**: 공개 GitHub PR #1의 실제 `macos-15` inventory에서 Xcode 16.4와 iPhone 16/iOS 18.5 조합을 확인했다. iPhone 16의 393x852 viewport는 Figma source와 일치하며, toolchain을 고정해야 글꼴·safe area·system chrome 변경을 기능 회귀와 구분할 수 있다.

**트레이드오프**: runner image에서 이 Xcode 또는 runtime이 제거되면 CI가 의도적으로 실패한다. 기준선 변경은 자동 fallback하지 않고 Figma reference 재검토와 ADR 갱신을 요구한다. 현재 홈은 placeholder이므로 visual report는 parity gate가 아니며 홈 기능 작업에서 사람이 승인한 threshold를 활성화한다.

## 아직 확정하지 않은 결정

- 첫 macOS interactive 환경을 로컬 Mac, 원격 Mac 중 무엇으로 확보할지
- Sign in with Apple만 사용할지와 계정·초대 정책
- 사진 최대 변·압축 품질·파일 크기·사용자별 일일 quota
- public App Store 전환 시 Cloudflare Containers 월 5 USD를 승인할지 또는 다른 JVM origin을 사용할지

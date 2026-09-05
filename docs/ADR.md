# Architecture Decision Records

> 기준일: 2026-08-17

## 철학

Money Snap은 iPhone의 기록 경험과 개인정보 보호를 우선하는 작은 MVP다. 제품 정책과 Figma 정합성은 인프라 편의보다 우선하며, backend는 한 번에 배포하는 modular monolith로 시작한다. 무료 운영은 목표이지만 보안·테스트·Acceptance Criteria를 낮추지 않는다.

## 결정 상태

| ADR | 상태 | 결정 |
|---|---|---|
| ADR-001 | accepted | MVP는 native iOS 전용 |
| ADR-002 | accepted | Spring Boot modular monolith와 origin SQLite |
| ADR-003 | accepted | Cloudflare DNS·R2와 개발자 소유 Ubuntu Docker origin으로 무료 폐쇄형 MVP부터 시작 |
| ADR-004 | accepted | Figma node와 screenshot diff를 시각적 기준으로 사용 |
| ADR-005 | accepted | Windows 개발과 macOS iOS 검증 lane 분리 |
| ADR-006 | rejected | D1을 Spring Boot 주 데이터베이스로 사용하지 않음 |
| ADR-007 | accepted | Neon PostgreSQL 대신 origin SQLite 파일을 사용한다 |
| ADR-008 | accepted | 서버는 GitHub Actions CI/CD, iOS는 GitHub Simulator CI와 GitHub-hosted TestFlight CD 사용 |
| ADR-009 | accepted | Bundle ID와 iOS visual verification toolchain 고정 |
| ADR-010 | accepted | Sign in with Apple 단독 인증과 서버 소유 장기 session |
| ADR-011 | accepted | 기록 리마인더와 원격 알림은 MVP에서 제외 |
| ADR-012 | accepted | 사진 없는 개인 저장을 먼저 닫고 private 사진·그룹 공유를 별도 경계로 완성 |

## ADR-001: native iOS 전용 MVP

**결정**: MVP 클라이언트는 iOS 17 이상, Swift 6 language mode, SwiftUI, Swift Concurrency, Observation으로 작성한다. 사진 선택은 PhotosUI, API는 URLSession, 오늘의 소비 오브젝트 낙하·충돌은 SpriteKit을 SwiftUI 안에 포함해 구현한다. Android와 웹은 MVP에서 만들지 않는다.

**이유**: 사용자가 iOS 전용 MVP를 확정했고, 기존 Figma가 iPhone system chrome·SF Symbols·sheet·tab 감각을 전제로 한다. native 구현이 사진, safe area, 접근성, 물리 캔버스와 시각적 정합성을 가장 직접적으로 제어한다.

**트레이드오프**: Android·웹 코드 재사용을 포기한다. iOS build·Simulator·서명에는 macOS가 필요하다.

## ADR-002: Spring Boot modular monolith와 origin SQLite

**결정**: backend는 Java 21 LTS와 현재 확정 시점의 Spring Boot 4.1 계열로 시작한다. Gradle, Spring Web, Spring Security, Validation, Spring JDBC, Flyway, origin SQLite를 사용한다. 배포 단위는 하나이며 package-by-feature로 `identity`, `snap`, `group`, `media` 경계를 둔다. API 경계는 versioned REST/JSON과 OpenAPI 3.1이다.

**이유**: 사용자가 Spring Boot를 확정했다. 개인 우선 기록, 수정·삭제 전파, 그룹 membership, 금액 공개 projection은 관계형 무결성과 서버 트랜잭션이 중요하다. Java 21은 무료·저사양 JVM host와 컨테이너에서 호환성이 넓은 LTS 기준이다.

**트레이드오프**: Workers-only 구조보다 메모리와 cold start가 크고 JVM origin 운영이 필요하다. microservice, Kafka, Redis, GraphQL, 실시간 socket과 완전한 offline sync는 MVP에서 도입하지 않는다.

## ADR-003: Cloudflare DNS·R2와 Ubuntu Docker origin

**결정**: 첫 폐쇄형 TestFlight MVP는 개발자 소유 Ubuntu 서버에서 Spring Boot OCI image를 Docker로 실행한다. Cloudflare는 `moneysnap-server.ansandy.co.kr` DNS와 private R2 Standard에 사용하고, 기존 Nginx Proxy Manager가 HTTPS를 host `9090` origin으로 전달한다. API 앞에 별도 Worker gateway나 named Tunnel을 두지 않는다.

공개 App Store 출시 전 또는 exit 기준 도달 시 origin을 재평가한다. Cloudflare에 Spring Boot를 직접 배포하기로 하면 Containers로 이동하되 Workers Paid의 월 최소 5 USD와 초과 과금을 별도 승인한다. 외부 무료 JVM host는 공식 무료 조건과 cold start를 실제 검증한 경우에만 Tunnel 대안으로 채택한다.

**이유**: 표준 Workers에는 JVM이 없고 Cloudflare Containers는 Spring Boot를 실행할 수 있지만 무료 티어가 없다. 이미 운영 중인 Ubuntu Docker/Nginx Proxy Manager/Prometheus/Grafana를 재사용하면 추가 compute 비용 없이 Spring Boot를 실행하고 관찰할 수 있다. R2의 S3-compatible private object storage는 저사용자 사진 MVP에 적합하다.

**트레이드오프**: port-forward와 Nginx Proxy Manager가 origin 공개 경계가 되므로 host patch, firewall, TLS와 proxy 설정을 직접 운영해야 한다. host 전원·인터넷·backup도 단일 장애점이다. 공개 출시 전 Cloudflare Tunnel 또는 managed origin으로 전환할지 재평가하고, 공개 출시·DAU 20 초과·30분 이상 장애·주 2회 사용자 영향 장애 중 하나면 무료 origin 결정을 다시 연다.

## ADR-004: Figma source of truth와 visual regression

**결정**: [Money Snap - Product Design](https://www.figma.com/design/IDNeYlc3584NY9YhsyUQYE/Money-Snap---Product-Design?node-id=0-1&t=lW8FBJFfcXo3cHEC-1)을 시각적 source of truth로 사용한다. 화면 작업은 실제 frame node ID, 393x852 reference screenshot, 추출 asset과 token을 고정한 뒤 SwiftUI snapshot과 overlay/diff를 통과해야 완료된다. 첫 기준선은 홈 `9:2`이며 구현 전에는 차이를 report-only로 기록한다.

**이유**: 사용자는 Figma와 거의 동일한 결과를 요구한다. 화면 이름만 참조하면 디자인 변경과 구현 오차를 추적할 수 없지만 node ID와 고정 fixture는 차이를 반복 검증할 수 있다.

**트레이드오프**: macOS Simulator와 screenshot baseline 관리 비용이 생긴다. Figma의 React/Tailwind 출력은 production 코드로 사용하지 않으며 SwiftUI로 변환한다. asset URL이 만료되기 전에 원본을 저장소 asset catalog로 가져와야 한다.

## ADR-005: Windows authoring과 macOS verification 분리

**결정**: Windows는 Spring Boot 전체 개발, Swift·Xcode 프로젝트 파일 작성과 Git 작업에 사용한다. Xcode 실행, iOS SDK build, Simulator, SwiftUI preview, signing, archive, TestFlight/App Store upload, pixel verification은 macOS lane에서 수행한다. Simulator CI는 GitHub-hosted `macos-15`가 소유하고, TestFlight archive는 App Store Connect iOS 26 SDK 요구 때문에 `macos-26` / Xcode 26이 소유한다. interactive pixel tuning과 로컬 device Run만 실제 Mac/Xcode가 필요하다.

**이유**: Apple이 배포하는 Xcode toolchain은 지원 macOS를 요구한다. 유료 Apple Developer 계정은 배포 권한을 제공하지만 Windows에 Xcode runtime을 제공하지 않는다. GitHub-hosted macOS는 Windows-only 개발자가 레포를 나누지 않고 archive/upload를 돌릴 수 있다.

**트레이드오프**: Mac 없이 첫 TestFlight 업로드는 가능하지만, Figma pixel tuning과 Xcode UI 디버깅은 원격 또는 실제 Mac이 필요하다.

## ADR-006: D1을 Spring Boot 주 DB에서 제외

**결정**: D1과 Hyperdrive를 MVP Spring Boot의 persistence 경로에서 사용하지 않는다. 주 저장소는 ADR-007의 origin SQLite다.

**이유**: D1은 SQLite 기반 Workers binding/SQL API이며 외부 애플리케이션용 JDBC wire endpoint를 제공하지 않는다. 외부 접근에는 proxy Worker가 필요해 Spring JDBC의 connection·transaction 의미와 맞지 않는다. Hyperdrive도 Workers가 외부 Postgres에 접근할 때 사용하는 binding이지 Spring Boot용 JDBC endpoint가 아니다.

**트레이드오프**: D1의 무료 5GB와 hard quota를 활용하지 못한다. origin SQLite는 같은 프로세스의 JDBC 트랜잭션을 직접 사용한다.

## ADR-007: Origin SQLite (Neon PostgreSQL 대체)

**상태**: accepted (2026-09-05 사용자 결정. Neon Free PostgreSQL을 대체한다)

**결정**: 개발과 폐쇄형 TestFlight origin은 Ubuntu Docker 볼륨의 SQLite 파일 하나를 사용한다. Spring runtime과 Flyway는 같은 `MONEYSNAP_SQLITE_URL`을 쓰고 Hikari pool은 1이다. 테스트는 임시 SQLite 파일이며 Testcontainers PostgreSQL과 Neon datasource는 제거한다. Neon 기존 데이터는 compute 중단으로 dump하지 않고 빈 SQLite로 시작한다.

**이유**: 상시 Spring Boot가 Neon 연결을 붙잡고 Free CU-hour를 소진했다. Money Snap 데이터량은 SQLite로 충분하고 origin은 이미 단일 컨테이너다. PostgreSQL wire와 Neon 이중 credential은 이 규모에서 운영 비용만 만든다.

**트레이드오프**: SQLite는 writer가 하나라 origin 컨테이너를 수평 확장할 수 없다. 파일 백업·권한·WAL은 Ubuntu 볼륨이 담당한다. PostgreSQL 전용 SQL과 Testcontainers 검증은 사라진다.

## ADR-008: GitHub Actions 서버 CD와 iOS TestFlight CD 분리

**결정**: Spring Boot의 test·JAR·Docker image packaging과 development deployment orchestration은 GitHub-hosted Ubuntu에서 수행한다. 성공한 `main` image artifact만 pinned SSH host key로 개발자 소유 Ubuntu Docker origin에 전송한다. iOS pull request native test는 path-scoped GitHub-hosted `macos-15`에서 Apple 개발 credential·provisioning 없이 실행하되 Simulator app·test host는 Keychain entitlement를 위해 Xcode 기본 ad-hoc(`Sign to Run Locally`) 서명을 사용한다. archive·internal TestFlight 업로드는 GitHub-hosted `macos-26`의 `ios-testflight` environment가 소유한다. App Store Connect API key는 PR/iOS test job과 `server-development`에 넣지 않는다. DNS/Nginx Proxy Manager와 monitoring lifecycle은 application release workflow와 분리한다.

모든 GitHub Action reference는 전체 commit SHA로 고정하고 Dependabot이 갱신한다. workflow 기본 권한은 `contents: read`다. server secret은 `server-development` environment를 통과한 `main` deployment job과 Ubuntu mode `600` runtime file에만 존재하며 pull request CI나 artifact에는 전달하지 않는다.

**이유**: public repository에서 persistent self-hosted runner를 제거하면 PR 또는 workflow 변경이 장기 실행 host를 침해할 면적이 줄어든다. GitHub-hosted runner가 매 run 격리된 환경에서 image를 만들고, pinned SSH identity와 checksum으로 배포 경계를 고정한다. iOS는 같은 GitHub macOS runner가 PR Simulator feedback과 `ios-testflight` archive를 담당하므로 레포를 나누거나 첫 Xcode Cloud workflow용 Mac이 필요하지 않다.

**트레이드오프**: GitHub-hosted deployment job이 Ubuntu SSH private key를 일시적으로 사용하므로 environment branch policy, pinned known_hosts, secret scanning과 key rotation이 필수다. 현재 activation은 사용자 제공 root key를 사용했으므로 최소 권한 deploy account로 축소하는 hardening 작업이 남는다. 자동 image rollback과 양방향 DB migration을 결합하지 않으며 schema는 expand-first 호환성을 별도 AC로 요구한다.

## ADR-009: Bundle ID와 iOS visual verification 기준선

**결정**: Money Snap의 최종 Bundle ID는 `com.ansandy.moneysnap`이다. GitHub iOS CI의 visual verification 기준선은 Xcode 16.4, iPhone 16, iOS 18.5, 393x852 points로 고정한다. Simulator UDID는 runner마다 달라지므로 device·runtime으로 찾고, app screenshot, Figma reference, overlay, diff와 수치 report를 artifact로 남긴다. iOS deployment target은 17 이상을 유지한다.

**이유**: 공개 GitHub PR #1의 실제 `macos-15` inventory에서 Xcode 16.4와 iPhone 16/iOS 18.5 조합을 확인했다. iPhone 16의 393x852 viewport는 Figma source와 일치하며, toolchain을 고정해야 글꼴·safe area·system chrome 변경을 기능 회귀와 구분할 수 있다.

**트레이드오프**: runner image에서 이 Xcode 또는 runtime이 제거되면 CI가 의도적으로 실패한다. 기준선 변경은 자동 fallback하지 않고 Figma reference 재검토와 ADR 갱신을 요구한다. 현재 홈은 placeholder이므로 visual report는 parity gate가 아니며 홈 기능 작업에서 사람이 승인한 threshold를 활성화한다.

## ADR-010: Sign in with Apple 단독 인증과 지속 session

**결정**: MVP identity provider는 Sign in with Apple 하나만 사용한다. 서버가 Apple credential을 검증·교환하고 15분 access token과 180일 inactivity window를 가진 rotating refresh session을 발급한다. iOS는 refresh credential을 Keychain에 저장한다. 로그아웃은 현재 기기 session만 폐기하고, 계정 탈퇴는 재인증 뒤 모든 session·사용자 데이터를 삭제하고 Apple token을 revoke한다.

**이유**: iOS 전용 MVP에서 별도 비밀번호 계정과 여러 provider를 운영할 이유가 없으며 Apple 로그인은 사용자 진입 마찰과 credential 보관 범위를 줄인다. 앱 자체 session을 사용하면 Apple identity token을 매 API 요청에 재사용하지 않고 사용자 경험과 폐기 범위를 제어할 수 있다.

**트레이드오프**: 실제 로그인과 token revoke에는 Apple explicit App ID, server key와 macOS/device 검증이 필요하다. 서버는 Apple key rotation, server-to-server account event와 refresh token 암호화를 운영해야 한다.

## ADR-011: 알림은 MVP에서 제외

**결정**: 점심·저녁 고정 리마인더를 포함한 iOS 로컬 알림과 APNs 원격 알림을 MVP에서 구현하지 않는다.

**이유**: 알림은 단순한 시간 trigger 외에도 권한 요청, 거부 복구, 시간대, 기록 완료 후 취소, 설정과 피로 방지 정책이 필요하다. 첫 MVP는 알림 없이 핵심 기록 루프의 반복 사용성을 먼저 검증한다.

**트레이드오프**: 초기 사용자의 재방문을 앱이 직접 상기시키지 못한다. 실제 사용 데이터에서 기록 누락이 핵심 문제로 확인되면 별도 기능으로 다시 연다.

## ADR-012: 개인 저장, private 사진과 그룹 공유 경계

**결정**: Snap은 `1...999,999,999 KRW` category+amount 개인 기록으로 먼저 저장하며 사진은 선택이다. 단계 3은 사진 없는 durable record를 먼저 완성하고 단계 6에서 camera·PhotosUI·JPEG 정규화와 private R2를 함께 연결한다. 사진은 Snap당 active image 한 장, 최대 변 `1600px`, `2,097,152 bytes`, EXIF 제거를 요구한다. server `Clock`과 제출된 tzdb region `ZoneId` 또는 `UTC`로 current day·직전 day만 받아 immutable `localDay`로 저장한다.

사진 grant는 최근 24시간 completed+nonexpired pending 20건과 active+pending `7,000,000,000 bytes` storage guardrail을 transaction으로 예약한다. direct PUT이 exact byte/type/checksum 경계를 실제로 강제하지 못하면 unrestricted grant를 발급하지 않고 Spring Boot bounded stream fallback을 사용한다.

그룹은 owner 한 명과 member, owner 포함 최대 20명이고 금액 공개 여부는 생성 시 고정한다. 초대는 최소 128-bit entropy, hash-only storage, 168시간, group당 active 하나다. 공유는 이미 저장된 개인 Snap 한 건에서 Home의 명시적 action으로 group 한 곳에만 수행하며 취소·실패가 개인 save를 되돌리지 않는다. 사진 없는 공유 Snap과 대표 Snap은 category별 고정 placeholder와 최신 `sharedAt`을 사용한다.

**이유**: 사진 upload를 record의 선행 조건으로 만들면 local persistence, object storage와 UI가 순환 의존하고 사진을 찍기 어려운 상황의 10초 기록을 막는다. 개인 저장과 share command를 분리하면 기본 비공개를 transaction 경계로 보장하고 네트워크·membership 실패가 원본 기록을 잃게 하지 않는다. 고정 quota와 immutable visibility는 폐쇄형 무료 MVP의 비용과 privacy 의미를 사용자가 예측할 수 있게 한다.

**트레이드오프**: 단계 3에서는 제품의 사진 중심 매력이 제한되고 단계 6에 실제 R2 contract test 비용이 집중된다. 한 Snap·한 group씩 공유하므로 여러 group 사용자는 action을 반복해야 한다. visibility 변경, owner 양도, 여러 사진을 한 Snap으로 묶기와 batch share는 MVP 이후로 미룬다.

## 아직 확정하지 않은 결정

- 첫 macOS interactive 환경을 로컬 Mac, 원격 Mac 중 무엇으로 확보할지
- public App Store 전환 시 Cloudflare Containers 월 5 USD를 승인할지 또는 다른 JVM origin을 사용할지

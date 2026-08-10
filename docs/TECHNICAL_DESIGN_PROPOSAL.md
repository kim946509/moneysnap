# Money Snap MVP 기술 설계 계획

> 상태: revised baseline
>
> 기준일: 2026-08-09
>
> 사용자 확정: iOS 전용, Spring Boot backend, Cloudflare 사용, Figma 고정밀 구현, 소규모 단계 무료 우선

## 결론

다음 조합으로 진행한다.

- iOS: SwiftUI native, Swift Concurrency, Observation, PhotosUI, URLSession, SpriteKit
- API: Java 21 LTS, Spring Boot 4.1 계열, Gradle, REST/JSON, OpenAPI 3.1
- 데이터: Neon PostgreSQL 18 dev/prod 분리, Flyway, Spring Data JPA
- 사진: private Cloudflare R2 Standard, AWS SDK for Java v2, short-lived presigned PUT/GET
- 무료 폐쇄형 배포: Cloudflare DNS → Nginx Proxy Manager → 개발자 소유 Ubuntu Docker의 stateless Spring Boot origin
- iOS CI: Apple Developer Program에 포함된 Xcode Cloud 월 25시간, 단 최초 workflow와 화면 조정에는 Mac/Xcode 필요
- 디자인 검증: Figma frame node별 393x852 reference와 SwiftUI snapshot overlay/diff

표준 Cloudflare Workers에는 JVM이 없고 Cloudflare Containers는 Workers Paid 전용이라 월 최소 5 USD다. 현재는 이미 운영 중인 Ubuntu Docker/Nginx Proxy Manager를 재사용해 추가 cloud compute 비용 없이 시작한다. 공개 출시 단계에서는 Cloudflare Tunnel, Containers 또는 managed JVM origin을 다시 비교한다.

공식 근거와 후보 수치는 [SPRING_CLOUDFLARE_RESEARCH.md](SPRING_CLOUDFLARE_RESEARCH.md), 확정 결정은 [ADR.md](ADR.md), 구현 경계는 [ARCHITECTURE.md](ARCHITECTURE.md)를 따른다.

## 세 대안 비교

| 대안 | 월 고정 cloud compute | Spring Boot | 운영 적합성 | 판단 |
|---|---:|---|---|---|
| Cloudflare Containers + PostgreSQL + R2 | 최소 $5 | 직접 실행 | public MVP 후보 | 무료 조건 때문에 지금 보류 |
| 무료 JVM host + Cloudflare edge/R2 + 무료 PostgreSQL | $0 가능 | 실행 가능 | 약 1분 cold start와 비운영 조건 | host 실측 후 보조 대안 |
| 자체 Ubuntu Docker + NPM + Cloudflare DNS/R2 | 추가 cloud compute $0 | 직접 실행 | 폐쇄형 TestFlight만 | **첫 단계 채택** |
| Workers + D1 + R2 | $0 가능 | 불가 | Cloudflare-native | 사용자 고정 조건과 충돌해 제외 |

무료 단계는 10~20명 내외의 신원을 아는 tester, 4~8주, uptime 약속 없는 폐쇄형 TestFlight로 제한한다. public App Store 배포 전에 origin 결정을 다시 연다.

## 기술을 사용하는 방식

### SwiftUI와 Figma

화면을 먼저 공통 컴포넌트로 추상화하지 않는다. 실제 frame 하나를 기준으로 vertical slice를 완성하고 반복되는 표현만 `MoneySnapVisualSystem`으로 승격한다.

1. 작업 항목에 Figma frame node ID와 393x852 screenshot을 고정한다.
2. design context에서 정확한 color, font, spacing, radius, shadow, asset을 추출한다.
3. SF Symbol은 동일 system name, 원본 사진·SVG는 exact asset을 사용한다.
4. SwiftUI snapshot을 reference와 overlay/diff한다.
5. 고정 Simulator/OS에서 safe area, keyboard, sheet, tab과 motion을 확인한다.
6. 차이가 남으면 baseline을 자동 갱신하지 않고 원인을 리뷰한다.

첫 구현 순서는 홈 `9:2` → 금액 입력 완료 `153:4156` → 그룹 목록 `75:86` → 그룹 상세 `77:163` → Snap 상세 `77:582` → 보관함 `77:681` → 마이 `77:798`이다. 홈의 소비 오브젝트는 SwiftUI 위에 SpriteKit scene을 포함해 낙하·충돌을 구현하고 reduce-motion에서는 정적 layout과 짧은 fade/scale로 대체한다.

### Spring Boot modular monolith

`identity`, `snap`, `group`, `media` 네 feature Module로 시작한다.

- `snap`: 개인 우선 기록, 수정·삭제, 오늘 캔버스 projection
- `group`: membership, 저장 후 공유, amount-visible/hidden projection
- `media`: upload intent, R2 grant, 완료 검증, orphan/delete 정리
- `identity`: 외부 identity 검증과 service session

controller와 repository를 Interface로 삼지 않는다. 사용 사례 수준의 `SnapJournal`, `GroupSharing`, `MediaVault`가 깊은 Interface다. DB, R2, Apple identity와 runtime 위치만 교체 가능한 Seam으로 둔다.

amount-hidden group DTO에는 금액을 nullable로 넣지 않는다. 금액, 총액과 금액에서 계산한 크기·정렬 필드 자체가 없는 별도 schema로 만들어 client 실수로 유출할 수 없게 한다.

### PostgreSQL

PostgreSQL은 Snap 원본, group membership, share 관계, media 상태와 멱등 ledger를 소유한다. Flyway migration만 schema 변경 경로로 사용한다. 테스트에서는 Testcontainers PostgreSQL로 실제 constraint와 transaction을 검증한다.

D1은 Workers binding/HTTP API 중심이고 Spring Data JPA가 사용할 JDBC endpoint가 없으므로 사용하지 않는다. 개발은 Neon Free `moneysnap-dev`, 폐쇄형 TestFlight는 별도 `moneysnap-prod`를 사용한다. runtime은 pooled endpoint와 `moneysnap_app`, Flyway·dump/restore는 direct endpoint와 owner로 분리한다. 상시 Docker Compose DB는 사용하지 않고 테스트에서만 PostgreSQL 18 Testcontainers를 일회성으로 기동한다.

Neon Free 한도는 project당 storage 0.5GB, 월 100 CU-hour와 5GB public network transfer다. 초과 과금 대신 compute 중단이 발생할 수 있으므로 60/70% 사용량을 관찰하고 공개 출시 전 region, backup, SLA와 이전 계획을 재평가한다.

### R2 사진 보관

R2 bucket은 private로 유지한다. iOS가 Spring Boot에 upload intent를 보내면 서버가 인증·quota·MIME·size를 검사하고 단일 object에 대한 짧은 presigned PUT을 발급한다. 업로드 후 서버가 metadata를 확인한 뒤에만 Snap에 연결할 `ImageRef`를 활성화한다.

사진 byte는 Spring Boot와 Tunnel을 통과하지 않는다. iOS에서 최대 변 축소, 압축과 위치 EXIF 제거를 먼저 수행한다. DB에는 permanent URL이 아니라 opaque image ID와 object key만 저장한다. download도 현재 owner/membership을 확인한 뒤 짧은 signed GET을 발급한다.

R2 Standard 무료 범위는 2026-08-08 resource 생성 시 월 10GB, Class A 100만, Class B 1,000만, 인터넷 egress 무료로 다시 확인했다. APAC에 private Standard bucket `moneysnap-media-dev`, `moneysnap-media-prod`를 만들었고 원격 PUT/GET/DELETE 검증을 통과했다.

### Cloudflare free guardrail

- R2 Standard 외의 Images transform, Data Catalog, R2 SQL, Queue, Workers AI는 꺼 둔다.
- 최대 이미지 크기와 사용자별 일일 upload 수를 server grant에서 강제한다.
- 활성 media 추적량 6GB에 경고, 7GB에 신규 upload kill switch를 적용하고 읽기·삭제는 유지한다.
- 월 operation 사용량을 dashboard와 내부 counter로 대조한다.
- Cloudflare budget alert는 $1 이상 낮은 값으로 두되 hard cap이 아니고 최대 하루 늦게 도착할 수 있음을 운영 문서에 표시한다.
- 승인된 R2 dev/prod bucket 외의 과금 가능 resource 생성, DNS/Tunnel 변경, secret 등록과 Containers 전환은 실행 전에 승인 경계를 다시 확인한다.

## Windows와 Xcode 운영 방식

Windows에서도 repository, Swift source, asset, `.xcodeproj` 관련 파일을 작성할 수 있고 Spring Boot는 전체 build/test가 가능하다. 그러나 Apple 공식 Xcode, iOS SDK build, Simulator, SwiftUI Preview, signing, archive는 macOS가 필요하다.

권장 lane은 다음과 같다.

- Windows: 일상적인 Swift·Java authoring, Gradle test, contract와 asset 작업
- Mac/Xcode 1회: scheme, signing, App Store Connect app record, 첫 Xcode Cloud workflow 구성
- Xcode Cloud: push 기반 build, unit/UI test, archive와 TestFlight 전달
- interactive Mac: Figma pixel tuning, Simulator·실기기 동작 확인

Apple Developer 계정 결제가 되어 있으므로 Xcode Cloud 월 25시간은 추가 비용 없이 쓸 수 있다. 빠른 unit workflow는 pull request, 전체 screenshot/XCUITest와 archive는 main 또는 수동 release에만 실행해 quota를 보호한다.

## TDD와 검증

모든 기능은 `.ai/templates/work-item.md`로 AC를 고정하고 실패 테스트부터 시작한다.

- backend: JUnit, Spring test, Testcontainers PostgreSQL, authorization negative tests, OpenAPI contract
- iOS: Swift Testing, in-memory Adapter, snapshot test, XCUITest
- visual: Figma overlay/diff와 사람이 승인한 baseline
- security: owner/non-member/left-member/hidden-group, expired signed URL, duplicate mutation
- 배포: container/JAR smoke test, Tunnel recovery, DB restore drill, R2 contract test

첫 애플리케이션 source 작업에서는 `code-review-graph`가 없으면 full build한다. 그 뒤 의미 있는 변경 묶음마다 incremental update → minimal context → risk에 맞는 change detection → finding TDD 수정 → test → graph 재update를 수행한다.

## 구현 로드맵

### Phase 0 — 실행 기반

1. Mac/Xcode 접근 경로와 첫 Xcode Cloud workflow 방법 확정
2. **완료**: monorepo directory, OpenAPI skeleton, Spring Boot, PostgreSQL Testcontainers, iOS project scaffold
3. **부분 완료**: backend build/test와 Windows iOS 정적 검증을 `AGENTS.md`에 기록; macOS native build/test는 대기
4. **완료**: 최초 `code-review-graph` full build와 change detection
5. **repository 준비 완료**: server GitHub Actions CI/CD, iOS GitHub Simulator CI와 Xcode Cloud hook. remote workflow run, Windows runner/environment secret, Xcode Cloud activation은 외부 gate 대기

### Phase 1 — 개인 Snap vertical slice

1. `SnapJournal.record` 실패 테스트와 PostgreSQL migration
2. Figma 홈 `9:2` static fixture snapshot
3. 금액 입력 `153:4156`, 사진 선택·압축, R2 in-memory Adapter
4. record 성공 후 오늘 캔버스 반영
5. SpriteKit physics와 reduce-motion

### Phase 2 — 실제 media와 수정·삭제

1. private R2 upload grant와 complete 검증
2. Snap 상세 `77:582`의 가격·카테고리 수정과 삭제
3. orphan/delete cleanup와 복구 테스트
4. R2 quota·kill switch 검증

### Phase 3 — group 공유

1. 그룹 생성·초대·공개 설정 정책을 제품 문서에서 먼저 확정
2. 저장 후 별도 share command와 membership authorization
3. visible/hidden DTO 보안 회귀 테스트
4. 그룹 목록 `75:86`, 상세 `77:163` snapshot/XCUITest

### Phase 4 — 폐쇄형 무료 TestFlight

1. Ubuntu Docker Spring Boot와 기존 private R2, Neon backup·restore 절차를 검증
2. Docker restart policy·Nginx Proxy Manager·Prometheus/Grafana recovery와 external health 확인
3. Xcode Cloud archive와 TestFlight closed cohort
4. 성능, 장애, R2/DB 사용량을 4~8주 관찰

### Phase 5 — public readiness gate

다음 하나라도 충족하면 Tunnel 무료 단계를 끝낸다.

- 공개 App Store 심사 또는 지인 밖 사용자를 받음
- DAU 20 또는 등록 사용자 100 초과
- 30분 이상 장애 1회 또는 한 주 사용자 영향 장애 2회
- p95 API 500ms 지속 초과 또는 upload 성공률 99% 미만
- R2/DB 무료 범위 70% 도달

이때 Cloudflare Containers 월 최소 5 USD와 외부 PostgreSQL을 우선 평가한다. 결제·배포는 별도 승인 없이는 실행하지 않는다.

## 다음 구현 전 결정 게이트

- interactive Mac을 로컬/원격 중 어떤 방식으로 확보할지
- Sign in with Apple 단일 인증과 tester allowlist 정책
- 사진 최대 변, 최대 byte, 일일 Snap quota
- snapshot과 XCUITest에 사용할 고정 Simulator 기종·iOS 17.x patch baseline
- 기존 `ansandy.co.kr` zone에서 사용할 API hostname과 dev/prod DNS route

이 항목은 architecture의 방향을 바꾸지 않지만 macOS native 검증 또는 해당 feature를 `ready`로 전환하기 전에 확정해야 한다.

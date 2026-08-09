# Money Snap 아키텍처

> 상태: accepted baseline
>
> 기준일: 2026-08-09

## 목표

- Figma 기준 iPhone 화면을 SwiftUI로 높은 정합도로 구현한다.
- 소비 기록은 항상 개인 기록으로 먼저 저장하고 공유는 별도 명령으로만 수행한다.
- 금액 비공개 그룹은 서버 응답 타입에서 금액과 금액 기반 크기 신호를 제거한다.
- Spring Boot 배포 위치와 object storage를 Adapter로 격리해 무료 폐쇄형 MVP에서 공개 origin으로 이동할 수 있게 한다.
- 작은 team과 낮은 사용량에 맞춰 하나의 iOS app, 하나의 Spring Boot deployable, 하나의 PostgreSQL로 시작한다.

## 전체 구조

```mermaid
flowchart LR
    IOS["SwiftUI iOS App"]
    EDGE["Cloudflare DNS"]
    NPM["Nginx Proxy Manager"]
    API["Ubuntu Docker / Spring Boot"]
    MON["Prometheus + Grafana"]
    DB[("Neon PostgreSQL")]
    R2[("Private R2 Standard")]
    MAC["macOS / Xcode Cloud"]
    FIGMA["Figma frame + screenshot"]

    IOS -->|"REST JSON"| EDGE
    EDGE --> NPM
    NPM -->|"host 9090"| API
    API -->|"management 9091 / main network"| MON
    API -->|"JDBC + Flyway"| DB
    API -->|"권한 검사와 signed grant"| R2
    IOS -->|"short-lived PUT / GET"| R2
    FIGMA -->|"node별 reference"| MAC
    MAC -->|"build, test, screenshot, archive"| IOS
```

무료 단계 origin은 개발자 소유 Ubuntu Docker host이며 기존 Nginx Proxy Manager가 HTTPS를 application port `9090`으로 전달한다. 이 topology는 폐쇄형 TestFlight에만 사용한다. 공개 출시 단계에서는 `EDGE → NPM → API` 구간을 Cloudflare Tunnel, Container 또는 별도 managed JVM origin으로 교체하고 API·DB·R2 Interface는 유지한다.

## 저장소 구조

```text
ios/                        # SwiftUI app, asset catalog, Swift tests, Xcode project
server/                     # Java 21 + Spring Boot + Gradle
contracts/
└── openapi/                # iOS와 API가 공유하는 versioned HTTP Interface
infra/
├── neon/                   # dev/prod project, 역할과 secret 계약
├── apple/                  # Apple Developer/App Store Connect 준비 계약
├── cloudflare/             # DNS/R2/향후 Containers 준비와 배포 설정
└── ubuntu/                 # Docker origin, rollback과 monitoring scrape 계약
docs/                       # 제품·기술 기준 문서
.ai/                        # AI 작업·검증 루프
```

`server/` scaffold는 Windows에서 test와 production JAR build를 통과했다. `ios/` project는 Windows 정적 검증만 통과했으며 macOS/Xcode build·test와 Simulator 검증 전에는 native 완료로 판정하지 않는다.

## iOS Module

| Module | 좁은 Interface | 숨기는 Implementation |
|---|---|---|
| `CaptureFlow` | 사진 선택부터 한 Snap 저장 완료까지 | PhotosPicker, 이미지 방향 보정·리사이즈·EXIF 제거, 여러 장 순차 처리, upload grant와 retry |
| `SnapJournalClient` | `today`, `record`, `revise`, `delete` | URLSession, bearer session, OpenAPI DTO, 오류 정규화 |
| `GroupSharingClient` | `groups`, `share`, `groupToday`, `memberToday` | membership API와 visible/hidden projection decoding |
| `MoneySnapVisualSystem` | 반복되는 color, type, spacing, tab, sheet, Snap object | Figma token, SF Symbol, asset catalog와 accessibility variant |
| `TodayCanvas` | 의미 데이터와 stable layout seed | SpriteKit scene, 낙하·충돌, reduce-motion fallback |

SwiftUI View는 R2 URL 생성, HTTP endpoint, JSON key, group 권한 규칙을 알지 않는다. preview와 snapshot에서는 production HTTP Adapter를 `InMemoryBackendAdapter`로 교체한다.

완전한 offline sync는 MVP에서 제외한다. 아직 전송하지 못한 현재 draft는 로컬에 보존할 수 있지만, server commit 전에 공유된 Snap으로 표시하지 않는다.

## Spring Boot Module

`server`는 package-by-feature modular monolith다.

```text
com.ansandy.moneysnap
├── identity/               # actor와 session, 외부 identity 검증
├── snap/                   # 개인 기록·수정·삭제·오늘 projection
├── group/                  # membership·선택적 공유·공개 정책 projection
├── media/                  # upload intent·R2 grant·삭제 정리
└── shared/                 # Money, IDs, Clock 등 작고 안정된 공통 값
```

각 feature는 `api → application → domain` 방향으로 호출하며 persistence와 외부 SDK Adapter는 feature 내부에 둔다. 다른 feature의 repository나 entity를 직접 참조하지 않고 application Interface를 호출한다. 범용 `service`, `util`, `repository` 패키지에 도메인 규칙을 모으지 않는다.

### 핵심 Interface와 불변 규칙

`SnapJournal`

- `record`는 group ID나 visibility를 입력받지 않고 개인 Snap만 만든다.
- 금액은 KRW 양의 정수로 저장하며 부동소수점을 사용하지 않는다.
- `revise`는 가격과 카테고리만 바꾼다.
- `delete` 성공 직후 개인·그룹 projection에서 Snap이 사라지고 media 삭제는 재시도 가능한 작업으로 넘긴다.
- client mutation ID로 record와 share의 중복 실행을 막는다.

`GroupSharing`

- 공유는 durable personal Snap에 대해서만 별도 수행한다.
- 현재 membership을 매 요청 확인한다.
- 같은 Snap·group 반복 공유는 멱등 성공이다.
- amount-visible 응답과 amount-hidden 응답은 다른 DTO다. hidden DTO에는 amount, total, amount-derived size와 order가 존재하지 않는다.

`MediaVault`

- object key는 서버가 만들고 client 입력을 경로로 사용하지 않는다.
- 인증, 소유권, MIME, byte size, 사용자·전체 quota를 통과한 경우에만 짧은 PUT grant를 발급한다.
- iOS가 R2에 직접 업로드한 뒤 `complete`가 실제 object metadata를 확인해야 image를 활성화한다.
- 읽기 grant도 소유자 또는 현재 group member를 확인한 뒤 발급한다.
- public bucket, 영구 URL, 앱 내 R2 credential을 금지한다.

## API 경계

- canonical Interface는 `contracts/openapi/moneysnap-v1.yaml`이 소유한다.
- path는 `/v1`으로 versioning하고 예상 가능한 오류는 안정된 code와 correlation ID를 반환한다.
- iOS는 생성되거나 검증된 typed client를 `SnapJournalClient` 뒤에서 사용한다.
- 존재하지 않는 자원과 접근할 수 없는 자원은 외부에서 구별되지 않는 `NOT_ACCESSIBLE`로 정규화한다.
- controller는 인증 actor와 request DTO를 application command로 바꾸는 일만 한다. 공개 정책·소유권은 domain/application Module에서 검사한다.
- health, metrics, actuator 상세 endpoint는 public mobile API hostname에 노출하지 않는다.

## 데이터 모델 기준

```text
users
sessions
snaps(id, owner_id, category, amount_won, local_day, image_id?, created_at, updated_at)
groups(id, amount_visibility)
group_memberships(group_id, user_id, role, joined_at)
snap_shares(snap_id, group_id, shared_at, unique(snap_id, group_id))
media_objects(id, owner_id, object_key, status, byte_size, checksum, created_at)
mutation_ledger(actor_id, mutation_id, result_ref, unique(actor_id, mutation_id))
cleanup_jobs(kind, target_id, attempts, next_attempt_at)
```

- `snaps`가 원본이고 `snap_shares`는 관계다. 공유용 Snap 복제본을 만들지 않는다.
- `image_id`는 불투명 식별자이며 permanent URL을 저장하지 않는다.
- 오늘 날짜는 client의 IANA timezone과 local date를 받아 서버가 허용 범위를 검증한 뒤 고정한다. 세부 시간대 정책은 기능 작업 전 AC로 확정한다.
- 그룹 생성·초대·설정 변경 필드는 제품 정책이 확정되기 전 schema에 추론해 추가하지 않는다.

## 사진 흐름

```mermaid
sequenceDiagram
    participant I as "iOS CaptureFlow"
    participant A as "Spring MediaVault"
    participant R as "Private R2"

    I->>A: "업로드 의도: size, MIME, checksum"
    A->>A: "인증·quota·object key 검사"
    A-->>I: "짧은 presigned PUT"
    I->>R: "압축·EXIF 제거 이미지 PUT"
    I->>A: "upload complete"
    A->>R: "HEAD metadata 검증"
    A-->>I: "opaque ImageRef"
```

Snap 저장은 활성 `ImageRef`만 허용한다. DB transaction과 R2 operation을 하나의 transaction처럼 가장하지 않는다. 미완료 upload intent, orphan object와 삭제 실패는 `cleanup_jobs`로 재시도한다.

## 보안과 개인정보 경계

- 인증 provider 결정 전에도 `IdentityVerifier` Seam을 유지하고 production Adapter와 test Adapter를 둔다. iOS app에 추출 가능한 고정 secret을 넣지 않는다.
- 모든 개인 Snap 조회는 owner를 조건에 포함하고, 모든 group 조회는 membership을 조건에 포함한다.
- 금액 비공개는 UI hide가 아니라 server projection과 DTO schema에서 강제한다.
- 가격, token, presigned URL query, 원본 사진명, DB URL을 log·analytics에 남기지 않는다.
- 사진 변환 시 위치를 포함한 불필요한 metadata를 제거한다.
- public Nginx Proxy Manager는 application `9090`만 전달하고 management `9091`과 actuator path는 외부에 노출하지 않는다.
- R2, DB, SSH credential은 저장소에 넣지 않고 최소 권한 secret으로 주입한다.
- 외부 배포, secret 등록, DNS 변경, 유료 플랜 활성화는 별도 release 승인을 요구한다.

## 무료 운영 guardrail

- R2 Standard만 사용하고 Images transformation, Data Catalog, R2 SQL, multipart upload는 MVP에서 비활성화한다.
- 사진 최대 변·파일 크기·일일 업로드 수를 구현 전 AC로 확정한다. 서버가 모든 upload grant에 적용한다.
- DB가 추적하는 활성 media 총량이 R2 10GB 무료 범위의 70%에 도달하면 신규 upload grant를 중지하고 읽기·삭제는 유지한다.
- Class A/B 추정량과 R2 dashboard 사용량을 대조하고 60/70% 알림을 둔다.
- Cloudflare budget alert는 다음 날 발송되는 정보성 알림이며 hard cap이 아님을 운영 문서에 명시한다.
- 자동 과금을 기술적으로 완전히 차단할 수 없는 resource는 사용자 승인 없이 생성하지 않는다.
- self-hosted 무료 단계는 신원을 아는 10~20명 내외, 최대 4~8주 폐쇄형 TestFlight로 제한한다.

## 테스트 전략

### Backend

- domain Interface에서 실패 테스트를 먼저 작성한다.
- PostgreSQL 18은 테스트 실행 중에만 Testcontainers로 기동해 실제 constraint, Flyway migration, transaction과 projection을 검증한다.
- 소유자·비회원·탈퇴 회원·hidden group에 대한 부정 권한 테스트를 필수로 둔다.
- R2는 `InMemoryObjectStoreAdapter`로 domain test를 실행하고, 실제 R2-compatible contract test는 승인된 integration 환경에서 분리한다.
- OpenAPI schema와 controller response의 contract test를 둔다.

### iOS

- `InMemoryBackendAdapter`를 사용한 Swift Testing으로 CaptureFlow와 화면 state를 TDD한다.
- 각 화면은 Figma node와 같은 fixture로 393x852 snapshot을 생성한다.
- 지정 Simulator/OS에서 XCUITest로 기록, 수정·삭제, 저장 후 공유, visible/hidden group을 검증한다.
- reduce motion, Dynamic Type, VoiceOver label과 touch target을 별도 확인한다.

### 변경 영향

- 애플리케이션 소스나 테스트가 처음 생기면 `code-review-graph`가 없으므로 full build한다.
- 이후 의미 있는 코드 변경 묶음마다 고정 base로 incremental update하고, 영향 분석에서 찾은 테스트 공백을 같은 TDD loop에서 처리한다.
- graph는 테스트와 Figma visual diff를 대체하지 않는다.

## iOS build와 배포 lane

- Windows: Spring Boot build/test, Swift source와 project file 작성, Figma asset 준비, CI/CD 정적 검증.
- GitHub-hosted Ubuntu CI: Java 21 test·bootJar와 digest-pinned Docker image archive를 만들며 secret을 주입하지 않는다.
- GitHub-hosted Ubuntu CD: 성공한 `main` image만 pinned SSH Ubuntu origin에 전송하고 container health 실패 시 이전 image로 rollback한다.
- GitHub-hosted `macos-15`: iOS·contract 변경에만 signing 없는 Simulator build/test를 실행한다.
- macOS/Xcode: SwiftUI preview, screenshot diff, interactive debugging과 첫 Xcode Cloud workflow 설정.
- Xcode Cloud: Apple-managed build/test/sign/archive와 internal TestFlight. Apple Developer Program 포함 25 compute hours/month 안에서 PR test와 main/release archive를 분리한다.
- interactive pixel tuning은 Xcode Cloud만으로 완료할 수 없으므로 실제 또는 원격 Mac 세션이 필요하다.

세부 trigger, environment secret, checksum, health와 rollback 계약은 `docs/CI_CD.md`가 소유한다. DNS, Nginx Proxy Manager와 monitoring 설정은 application CD가 만들거나 재시작하지 않는다.

## 금지할 구조

- SwiftUI View에서 직접 R2·DB·Cloudflare API 호출
- public R2 bucket 또는 장기 presigned URL
- group amount를 client가 받은 뒤 숨기기만 하는 구현
- 기록과 group 공유를 하나의 command로 결합
- Worker와 Spring Boot에 인증·권한·도메인 규칙을 중복
- D1 proxy Worker를 JPA database처럼 사용
- ephemeral container/local disk에 DB·사진·session 영구 저장
- 개발 편의를 위한 상시 Docker Compose PostgreSQL과 dev/prod DB 공유
- 기능별 microservice, Kafka, Redis, realtime socket을 근거 없이 선도입
- macOS build·snapshot evidence 없이 iOS 작업을 완료 처리

## 배포 전환 기준

다음 중 하나면 self-hosted 무료 origin을 종료하고 public origin 결정을 연다.

- 공개 App Store 심사 또는 지인 밖 사용자 모집
- DAU 20 또는 등록 사용자 100 초과
- 30분 이상 장애 1회 또는 한 주 사용자 영향 장애 2회
- p95 API 응답 500ms 초과가 지속되거나 upload 성공률 99% 미만
- RPO 24시간 또는 RTO 4시간을 만족하지 못함
- Ubuntu host 운영에 주 1시간 이상 소비
- 예상 R2/DB 사용량이 무료 범위의 70% 도달

Cloudflare Containers 채택 시 월 최소 5 USD, 예상 memory/CPU/disk, `sleepAfter`, max instance 1, 외부 PostgreSQL latency를 실제 부하로 검증하고 별도 승인한다.

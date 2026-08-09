# Spring Boot · Cloudflare · iOS 실행 가능성 조사

> 조사 기준일: 2026-08-08
> 접근일: 아래 모든 웹 자료 2026-08-08
> 상태: 기술 결정을 위한 조사 자료. 이 문서는 ADR이 아니며 외부 리소스를 생성하거나 배포하지 않았다.

## 1. 조사 질문과 결론

이번 조사는 다음 네 조건을 동시에 만족할 수 있는지 확인한다.

1. iOS 전용 MVP
2. Spring Boot 백엔드
3. Cloudflare 배포
4. 사용자가 적은 동안 월 추가 비용 0원 유지

공식 자료로 확인한 결론은 다음과 같다.

- **사실:** 표준 Cloudflare Workers에는 JVM 런타임이 없다. Workers는 JavaScript, TypeScript, Python, Rust를 우선 지원하고 그 밖의 언어는 WebAssembly 경로를 제공하지만, Spring Boot 애플리케이션을 JVM으로 실행하는 공식 배포 경로는 아니다. [Cloudflare Workers 지원 언어](https://developers.cloudflare.com/workers/languages/)
- **사실:** Cloudflare Containers는 2026-04-13에 정식 출시되었고 어떤 언어·런타임의 컨테이너 이미지도 실행할 수 있으므로 Spring Boot를 실행할 수 있다. 다만 **Workers Paid 전용**이며 계정당 최소 요금은 월 5 USD다. [Containers GA 공지](https://developers.cloudflare.com/changelog/post/2026-04-13-containers-sandbox-ga/), [Containers 개요](https://developers.cloudflare.com/containers/), [Workers 가격](https://developers.cloudflare.com/workers/platform/pricing/)
- **판단:** 따라서 **Spring Boot + Cloudflare 관리형 컴퓨트 + 월 0원**은 현재 동시에 충족할 수 없다. Cloudflare에 Spring Boot 컴퓨트를 직접 배포하려면 최소 월 5 USD를 받아들이거나, 컴퓨트는 외부/자체 호스트에 두고 Cloudflare를 DNS·프록시·Tunnel·R2 경계로 사용하는 하이브리드가 필요하다.
- **권고:** “Cloudflare에 직접 배포”가 절대 조건이면 `Cloudflare Containers + 외부 PostgreSQL + R2`를 선택하고 월 5 USD를 운영 하한으로 둔다. “추가 비용 0원”이 더 중요하면 닫힌 MVP 동안 `무료 JVM 호스트 또는 자체 호스트 + Cloudflare edge/Tunnel + R2 + 무료 PostgreSQL`을 사용하되, 무료 호스트의 긴 콜드 스타트와 비운영용 조건을 수용한다.

## 2. Cloudflare 런타임과 Spring Boot

### 2.1 표준 Workers

**공식 사실**

- Workers의 우선 지원 언어는 JavaScript, TypeScript, Python, Rust다. 그 밖의 언어는 WebAssembly로 컴파일하여 사용할 수 있고 문서에는 Kotlin도 예로 들지만, 이것은 JVM을 제공한다는 의미가 아니다. [지원 언어](https://developers.cloudflare.com/workers/languages/)
- Workers Free는 하루 100,000 요청과 호출당 CPU 10ms를 제공한다. 메모리는 isolate당 128MB다. [Workers 가격](https://developers.cloudflare.com/workers/platform/pricing/), [Workers 제한](https://developers.cloudflare.com/workers/platform/limits/)

**추론**

- Spring Boot는 일반적으로 JVM, classpath, 스레드, 파일·네트워크 런타임과 수백 MB 메모리를 전제로 한다. Cloudflare가 문서화한 Workers 런타임과 제한에는 JVM이 없으므로 표준 Workers에 Spring Boot JAR를 올려 실행하는 것은 지원되는 배포 방식이 아니다.
- Kotlin을 WebAssembly로 컴파일할 수 있다는 문구는 Kotlin/Wasm 프로그램의 가능성을 뜻할 뿐, Spring Boot/JVM 호환성을 뜻하지 않는다.

**Money Snap 적합성**

- Workers Free는 아주 얇은 리다이렉트, 요청 검증, 캐시 정책 같은 edge 코드에는 적합할 수 있다.
- Spring Security, Spring Data JPA, 도메인 트랜잭션을 포함한 주 백엔드를 Workers로 옮기려면 사실상 별도 TypeScript/Python 백엔드를 만드는 것이므로 이번 결정과 충돌한다.

### 2.2 Containers

**공식 사실**

- Containers는 2026-04-13부터 GA이며, Linux 계열 런타임과 기존 컨테이너 이미지를 실행한다. 문서상 이미지는 `linux/amd64`로 빌드해야 한다. [GA 공지](https://developers.cloudflare.com/changelog/post/2026-04-13-containers-sandbox-ga/), [개요](https://developers.cloudflare.com/containers/), [컨테이너 생명주기](https://developers.cloudflare.com/containers/platform-details/architecture/)
- Containers는 Workers Paid에서만 사용할 수 있다. Workers Paid는 계정당 월 최소 5 USD다. [Containers 개요](https://developers.cloudflare.com/containers/), [Workers 가격](https://developers.cloudflare.com/workers/platform/pricing/)
- 월 5 USD에는 메모리 25 GiB-hours, CPU 375 vCPU-minutes, 디스크 200 GB-hours가 포함된다. 초과분은 메모리·실사용 CPU·디스크를 각각 과금한다. Free 행은 모두 N/A다. [Workers 가격의 Containers 표](https://developers.cloudflare.com/workers/platform/pricing/#containers)
- 컨테이너는 요청 시 시작하고 유휴 타임아웃 뒤 정지할 수 있다. 정지하면 사용량 과금은 멈춘다. 완전히 정지된 상태의 콜드 스타트는 보통 1~3초지만 이미지 크기와 엔트리포인트에 따라 달라진다. [컨테이너 생명주기](https://developers.cloudflare.com/containers/platform-details/architecture/)
- 컨테이너 로컬 디스크는 임시 저장소다. sleep 후 새 인스턴스가 시작되면 새 디스크를 받는다. [컨테이너 생명주기](https://developers.cloudflare.com/containers/platform-details/architecture/#persistent-disk)

**추론**

- Spring Boot Docker 이미지는 Containers에 배포할 수 있다. JVM 시작 시간이 Cloudflare가 제시한 일반적인 1~3초에 더해질 수 있으므로 실제 이미지로 콜드 스타트를 측정해야 한다.
- scale-to-zero는 **초과 사용량을 줄이는 기능**이지 Workers Paid의 월 5 USD 기본료를 없애는 기능은 아니다.
- 임시 디스크 때문에 SQLite 파일, 업로드 사진, 로컬 세션을 컨테이너에 영구 저장하면 안 된다. DB는 외부 PostgreSQL, 사진은 R2처럼 컨테이너 밖에 두어야 한다.

## 3. Cloudflare 무료 계층의 역할

| 제품 | 2026-08-08 공식 무료 범위 | Spring Boot 조합 적합성 |
|---|---:|---|
| Workers | 100,000 요청/일, 호출당 CPU 10ms | 주 백엔드는 부적합. 선택적 edge 코드만 적합 |
| R2 Standard | 10 GB-month/월, Class A 100만/월, Class B 1,000만/월, 인터넷 egress 무료 | **매우 적합.** Java S3 SDK와 presigned URL 사용 가능 |
| D1 | 500만 row read/일, 10만 row write/일, 총 5GB | 사용량은 매력적이나 Spring Data JDBC/JPA에는 부적합 |
| Tunnel | 모든 플랜에서 사용 가능. 공개 IP 없이 outbound-only 연결 | 자체 호스트 Spring Boot origin 노출에 적합. 컴퓨트 호스팅을 제공하는 것은 아님 |
| Turnstile | 무료, 계정당 widget 20개, widget당 hostname 10개, challenge 무제한 | 웹 가입·관리 화면의 봇 방어 후보. native iOS의 일반 API 인증을 대체하지 않음 |

근거: [Workers 가격](https://developers.cloudflare.com/workers/platform/pricing/), [R2 가격](https://developers.cloudflare.com/r2/pricing/), [D1 가격](https://developers.cloudflare.com/d1/platform/pricing/), [Tunnel 개요](https://developers.cloudflare.com/tunnel/), [Turnstile 플랜](https://developers.cloudflare.com/turnstile/plans/).

### 3.1 R2

**공식 사실**

- R2 Standard 무료 범위는 월 10 GB-month, Class A 작업 100만 회, Class B 작업 1,000만 회이며 인터넷 egress는 무료다. Infrequent Access에는 이 무료 저장 계층이 적용되지 않는다. [R2 가격](https://developers.cloudflare.com/r2/pricing/)
- R2는 S3 호환 API를 제공하고 Cloudflare는 AWS SDK for Java v2 예제를 공식 제공한다. [R2 S3 시작하기](https://developers.cloudflare.com/r2/get-started/s3/), [AWS SDK for Java 예제](https://developers.cloudflare.com/r2/examples/aws/aws-sdk-java/)
- presigned URL은 특정 객체에 대한 GET, HEAD, PUT, DELETE를 1초~7일 동안 허용할 수 있다. URL 자체가 bearer token이므로 짧은 만료와 제한된 객체 키가 필요하다. [R2 presigned URL](https://developers.cloudflare.com/r2/api/s3/presigned-urls/)
- R2 bucket은 기본 비공개다. `r2.dev` 공개 주소는 개발용이며 rate limit이 있으므로 production 용도로 쓰지 말라고 문서가 안내한다. [R2 public bucket](https://developers.cloudflare.com/r2/buckets/public-buckets/)

**권고**

- 사진은 private R2 bucket에 저장한다.
- Spring Boot는 사용자와 그룹 권한을 확인한 뒤 짧은 TTL의 단일 객체 PUT/GET presigned URL만 발급한다.
- iOS가 R2로 직접 업로드하게 하여 사진 바이트가 Spring Boot를 통과하지 않도록 한다. API는 업로드 상태와 객체 키만 트랜잭션으로 관리한다.
- 비공개 그룹의 사진 URL도 회원 확인 뒤 발급하고, URL 로그·분석 이벤트에 query string이 남지 않게 한다.

### 3.2 D1과 Spring Data JDBC/JPA

**공식 사실**

- D1은 SQLite 기반 서버리스 DB이며 Workers binding API, SQL API, 관리용 REST API를 문서화한다. 외부 애플리케이션에서 접근하려면 Cloudflare 공식 튜토리얼은 proxy Worker를 만들도록 안내하며, 내장 REST API는 전역 Cloudflare API rate limit이 적용되어 관리 용도에 적합하다고 설명한다. [D1 개요](https://developers.cloudflare.com/d1/), [외부 접근용 proxy Worker 튜토리얼](https://developers.cloudflare.com/d1/tutorials/build-an-api-to-access-d1/)
- D1 Free는 하루 500만 row read, 10만 row write, 총 5GB를 제공하고 유휴 compute 요금은 없다. 무료 한도를 넘으면 해당 작업이 오류로 중단된다. [D1 가격](https://developers.cloudflare.com/d1/platform/pricing/)

**추론**

- 공식 API 목록에는 외부 서버가 접속할 PostgreSQL/MySQL식 wire protocol endpoint나 JDBC driver가 없다. 따라서 Spring Data JDBC/JPA의 일반적인 `DataSource`로 D1에 직접 연결하는 경로는 없다.
- Spring Boot가 proxy Worker에 SQL을 HTTP로 보내는 구조는 JPA의 트랜잭션·connection·ORM 의미론과 맞지 않고, 앱 백엔드 외에 별도 데이터 프록시와 인가 경계를 추가한다.

**권고**

- Spring Boot 선택을 유지하는 동안 D1을 주 데이터베이스로 선택하지 않는다.
- 관계형 무결성, Flyway migration, Spring Data JPA, 테스트 컨테이너를 그대로 사용할 수 있는 PostgreSQL을 선택한다.

### 3.3 Tunnel과 Turnstile

**공식 사실**

- Cloudflare Tunnel은 모든 플랜에서 제공되며, origin에 공개 IP나 inbound port를 열지 않고 `cloudflared`가 outbound-only 연결을 만든다. Cloudflare의 CDN, WAF, DDoS 보호 경계를 통과시킬 수 있다. [Tunnel 개요](https://developers.cloudflare.com/tunnel/)
- Cloudflare Zero Trust Free는 50명 미만 팀/PoC를 위한 0 USD 플랜이다. 유료 플랜과 달리 uptime SLA는 없다. [Cloudflare Zero Trust 가격](https://www.cloudflare.com/plans/zero-trust-services/)
- Turnstile Free는 계정당 widget 20개, widget당 hostname 10개, challenge 무제한이다. [Turnstile 플랜](https://developers.cloudflare.com/turnstile/plans/)

**추론과 권고**

- Tunnel은 서버를 대신 실행하지 않는다. 이미 켜져 있는 PC, NAS, VM에 Spring Boot와 `cloudflared`를 함께 운영할 때만 추가 cloud compute 요금을 피할 수 있다.
- 무료 플랜에는 SLA가 없고 origin 전원·인터넷·백업을 운영자가 책임지므로 공개 production보다는 개발·닫힌 베타에 한정한다.
- Turnstile은 JavaScript가 동작하는 브라우저 환경을 요구하며 native iOS에서는 `WKWebView`로 웹 페이지를 띄워야 한다. 따라서 일반 API 호출의 신뢰 경계로 사용하지 않는다. iOS에는 Sign in with Apple, 서버 세션/JWT, rate limit, 기기·행동 기반 abuse 방어를 별도로 설계한다. Turnstile은 추후 웹 초대·가입 화면 또는 WebView 마찰을 허용할 수 있는 고위험 동작에서 평가한다. [Turnstile mobile 구현](https://developers.cloudflare.com/turnstile/get-started/mobile-implementation/)

## 4. 현실적인 배포 선택지

### 선택지 A — Cloudflare Containers + PostgreSQL + R2

```text
iOS
  ├─ JSON API ─> Cloudflare Worker router ─> Spring Boot Container
  │                                           └─ JDBC ─> PostgreSQL
  └─ presigned PUT/GET ───────────────────────────────> private R2
```

**비용**

- Cloudflare Workers Paid 최소 월 5 USD.
- 낮은 사용량에서는 포함된 Container 사용량과 R2 무료 범위 안에 머물 가능성이 높지만, 실제 Spring Boot 메모리와 awake time을 측정해야 한다.
- PostgreSQL은 별도 무료 계층 또는 유료 서비스가 필요하다.

**장점**

- Spring Boot 컴퓨트가 실제 Cloudflare에 배포된다.
- 컨테이너 유휴 정지와 R2 직접 업로드로 사용량을 줄일 수 있다.

**위험**

- 월 0원은 불가능하다.
- JVM 콜드 스타트, 임시 디스크, Worker-to-Container routing을 기술 검증해야 한다.
- PostgreSQL이 Cloudflare 밖에 있으면 DB 왕복 지연과 connection 관리가 필요하다.

**판정:** “Cloudflare 직접 배포”가 우선이면 1순위다.

### 선택지 B — 무료 JVM 호스트 + Cloudflare edge/R2 + 무료 PostgreSQL

공식 무료 계층이 현재 확인되는 예시는 다음과 같다.

- Render Free web service: 512MB RAM, 0.1 CPU, workspace당 월 750시간. 15분 동안 요청이 없으면 sleep하고 다음 요청 때 약 1분 동안 기동한다. 로컬 파일은 임시 저장소이고 Render는 Free를 production에 사용하지 말라고 명시한다. [Render Free](https://render.com/docs/free), [Render instance type](https://render.com/docs/compute-plans/), [Render web service](https://render.com/docs/web-services)
- Neon Free PostgreSQL: 프로젝트당 월 100 CU-hours, 저장소 0.5GB, 최대 2 CU이며 신용카드와 시간 제한 없이 0 USD로 안내한다. [Neon 가격](https://neon.com/pricing)
- Supabase Free PostgreSQL 대안: 프로젝트당 DB 500MB, 1주 비활성 시 pause, 최대 활성 프로젝트 2개다. [Supabase 가격](https://supabase.com/pricing), [Supabase billing](https://supabase.com/docs/guides/platform/billing-on-supabase)

**권고 구성**

```text
iOS -> Cloudflare DNS/proxy -> Render Free Spring Boot -> Neon Free PostgreSQL
  └──────────────── presigned upload/download ───────> private R2
```

**판정:** 비용 0원을 최우선으로 하는 개발·내부 테스트·초기 닫힌 베타 후보지만, Render가 production 용도로 권장하지 않고 첫 요청이 약 1분 지연될 수 있으므로 일반 공개 MVP의 안정성 기준으로 삼지 않는다. 512MB에서 실행하려면 작은 JRE 이미지, 제한된 heap, 낮은 DB pool로 실제 검증해야 한다.

### 선택지 C — 자체 호스트 Spring Boot + Cloudflare Tunnel + R2

**구성**

- 기존 Windows/Linux PC, NAS 또는 소형 서버에서 Spring Boot와 PostgreSQL을 운영한다.
- `cloudflared`로 public hostname을 연결하고 사진은 R2에 둔다.

**판정:** 이미 24시간 켜져 있는 장비가 있다면 cloud compute 추가 비용을 0원에 가깝게 만들 수 있다. 다만 전기·장비 비용, 인터넷 장애, OS patch, backup, 모니터링, 단일 장애점을 직접 책임진다. 개발과 소규모 초대 베타에는 가능하지만 공개 production의 기본안으로는 권하지 않는다.

### 선택지 D — Workers + D1 + R2

**판정:** Cloudflare 무료 계층만으로 가장 단순하게 운영할 수 있지만 Spring Boot를 폐기하고 Workers용 백엔드를 새로 작성해야 한다. 사용자의 명시적 Spring Boot 결정과 충돌하므로 현재는 제외한다.

## 5. iOS 개발과 Windows의 정확한 경계

### 공식 사실

- Apple의 Xcode 시스템 요구사항은 각 Xcode 버전이 설치되는 지원 macOS 버전만 제시한다. 조사 시점 안정 버전인 Xcode 26.6은 macOS Tahoe 26.2~26.x를 요구한다. Windows용 Xcode는 Apple의 지원 대상에 없다. [Xcode 시스템 요구사항](https://developer.apple.com/xcode/system-requirements/)
- Apple은 iOS Simulator가 Mac의 Xcode/Device Hub에서 실행된다고 설명한다. 실제 기기 실행, provisioning profile 생성과 자동 signing도 Xcode에서 수행한다. [Simulator·기기 실행](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices)
- archive와 배포 서명은 Xcode 또는 macOS의 `xcodebuild` 경로로 수행된다. Xcode Cloud도 내부적으로 `xcodebuild archive`를 실행한다. [배포와 archive](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases/), [Xcode Cloud action](https://developer.apple.com/documentation/xcode/configuring-your-xcode-cloud-workflow-s-actions)

### 해석

- **Windows에서 가능:** Git clone/commit, Swift 소스와 리소스 편집, `.xcodeproj`/설정 파일의 텍스트 변경, 서버·공용 모델 테스트, cloud build 결과 확인.
- **Windows에서 Apple 공식 경로로 불가능:** Xcode 앱 실행, iOS SDK 로컬 build, Simulator 실행, interactive SwiftUI Preview, 기기 디버깅, signing·archive·App Store upload.
- 따라서 “Xcode 프로젝트를 Windows에서 세팅·편집할 수 있다”와 “Xcode toolchain을 Windows에서 실행할 수 있다”는 구분해야 한다. 전자는 파일 작업 범위에서 가능하지만 후자는 지원되는 macOS 실행 환경이 필요하다.

### Figma 고정밀 구현에 미치는 영향

Money Snap은 Figma와 거의 동일한 화면을 목표로 한다. cloud build 성공만으로는 글꼴 렌더링, safe area, Dynamic Type, 키보드, 실제 사진 비율, animation과 touch target을 눈으로 반복 확인할 수 없다. 따라서 다음 중 하나는 구현 시작 전에 확보해야 한다.

1. 로컬 Mac + 실제 iPhone
2. 원격으로 interactive 사용 가능한 Mac + 실제 기기/Simulator

Xcode Cloud는 자동 build/test/archive에는 유용하지만 interactive pixel-tuning 환경을 대체하지 않는다.

## 6. Apple Developer 계정과 Xcode Cloud

**공식 사실**

- Apple Developer Program은 연 99 USD이며 TestFlight/App Store 배포, 인증서·프로비저닝과 Xcode Cloud를 포함한다. 사용자는 이미 유료 가입 상태라고 밝혔다. [프로그램 포함 항목](https://developer.apple.com/programs/whats-included/)
- 회원에게 Xcode Cloud 월 25 compute hours가 추가 비용 없이 포함된다. 미사용 시간은 다음 달로 이월되지 않는다. Xcode Cloud 사용에는 Xcode 15 이상과 Apple Developer Program 회원 자격이 필요하다. [Xcode Cloud](https://developer.apple.com/xcode-cloud/), [시작하기와 요금](https://developer.apple.com/xcode-cloud/get-started/)
- Xcode Cloud는 GitHub/GitHub Enterprise, GitLab/self-managed GitLab, Bitbucket을 지원한다. [SCM 설정](https://developer.apple.com/documentation/xcode/source-code-management-setup)
- **첫 workflow는 Xcode에서 구성해야 한다.** 첫 build 이후에는 Xcode 또는 App Store Connect 웹에서 workflow를 생성·수정할 수 있고 App Store Connect API로 build/workflow를 관리할 수도 있다. [첫 workflow 구성](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow), [workflow reference](https://developer.apple.com/documentation/xcode/xcode-cloud-workflow-reference)

**권고 Windows 중심 흐름**

1. Mac/Xcode에서 앱 프로젝트, signing, scheme, App Store Connect app record와 첫 Xcode Cloud workflow를 한 번 구성한다.
2. 이후 Windows에서 Swift·Spring 코드를 편집하고 remote Git에 push한다.
3. Xcode Cloud가 build, unit/UI test, archive를 수행하고 결과는 App Store Connect 웹에서 확인한다.
4. 월 25시간을 지키기 위해 PR마다 빠른 unit build를 돌리고, 전체 UI test·archive는 main 또는 수동 release workflow로 제한한다.
5. 화면 정밀도와 실제 기기 문제는 별도의 interactive Mac 세션에서 검증한다.

## 7. 권고안과 의사결정 게이트

### 권고안

조사 시점의 Spring Boot 4.1.0은 Java 17 이상, Java 26 이하를 지원한다. Money Snap은 무료 JVM host와 컨테이너 호환성이 넓고 장기 지원 기준이 명확한 Java 21 LTS를 선택한다. [Spring Boot system requirements](https://docs.spring.io/spring-boot/system-requirements.html)

기술적으로 가장 일관된 목표 구조는 다음이다.

- iOS: SwiftUI native
- API: Spring Boot 컨테이너
- DB: PostgreSQL + Flyway + Spring Data JPA
- 사진: private Cloudflare R2 + Java S3 SDK + 짧은 presigned URL
- edge: Cloudflare DNS/proxy, 필요할 때만 얇은 Worker
- iOS CI: Xcode Cloud 월 포함 25시간

운영 단계는 비용 목표에 따라 분리한다.

1. **로컬 개발:** Windows에서 Spring Boot/PostgreSQL, Mac에서 iOS build·Simulator·기기 검증.
2. **닫힌 MVP 비용 0원 실험:** 선택지 B 또는 C. 콜드 스타트와 비운영용 조건을 AC에 명시한다.
3. **Cloudflare 직접 배포:** 선택지 A. Workers Paid 월 5 USD를 승인한 뒤 Containers로 이동한다.

### 구현 전 반드시 결정할 항목

1. `Cloudflare 직접 배포`와 `월 추가 비용 0원` 중 어느 쪽이 우선인지.
2. 초기 Mac/Xcode 구성과 이후 interactive Figma 검증에 사용할 Mac 접근 경로.
3. 닫힌 MVP에서 약 1분의 무료 호스트 콜드 스타트를 허용할지.
4. PostgreSQL 무료 공급자로 Neon, Supabase 또는 자체 호스트 중 무엇을 사용할지.
5. 예상 사진 수·평균 압축 크기로 R2 10GB 무료 범위에 몇 명·몇 개 Snap이 들어가는지.

## 8. 사실·추론·권고 경계

- 가격과 한도는 각 공급자의 2026-08-08 공식 페이지에 기반한다. 공급자가 이후 변경할 수 있으므로 실제 외부 리소스 생성 직전에 다시 확인해야 한다.
- “D1은 Spring Data JDBC/JPA에 부적합”은 Cloudflare가 공개한 binding/SQL/REST API와 외부 접근용 proxy 구조에서 도출한 기술 판단이다. Cloudflare 공식 JDBC driver가 존재하지 않는다는 조사 범위의 결론이며, 미래 기능을 부정하는 문장은 아니다.
- “Render Free에서 작은 Spring Boot를 실행할 수 있다”는 512MB/0.1 CPU와 Docker 지원에서 도출한 후보 판단이다. Money Snap 이미지와 JVM 옵션으로 build·기동·메모리·콜드 스타트를 측정하기 전에는 실행 가능성을 확정하지 않는다.
- “Xcode 프로젝트 파일 편집은 Windows에서 가능”은 파일이 Git으로 관리되는 소스라는 일반적 성질에 대한 판단이다. Apple이 Windows용 Xcode toolchain을 제공한다는 뜻이 아니다.

## 9. 주요 1차 자료

모든 링크 접근일은 2026-08-08이다.

- Cloudflare: [Workers 언어](https://developers.cloudflare.com/workers/languages/), [Workers 가격](https://developers.cloudflare.com/workers/platform/pricing/), [Containers GA](https://developers.cloudflare.com/changelog/post/2026-04-13-containers-sandbox-ga/), [Containers 생명주기](https://developers.cloudflare.com/containers/platform-details/architecture/), [R2 가격](https://developers.cloudflare.com/r2/pricing/), [R2 Java SDK](https://developers.cloudflare.com/r2/examples/aws/aws-sdk-java/), [R2 presigned URL](https://developers.cloudflare.com/r2/api/s3/presigned-urls/), [D1 가격](https://developers.cloudflare.com/d1/platform/pricing/), [D1 외부 접근](https://developers.cloudflare.com/d1/tutorials/build-an-api-to-access-d1/), [Tunnel](https://developers.cloudflare.com/tunnel/), [Turnstile 플랜](https://developers.cloudflare.com/turnstile/plans/)
- Apple: [Xcode 시스템 요구사항](https://developer.apple.com/xcode/system-requirements/), [Xcode Cloud](https://developer.apple.com/xcode-cloud/), [Xcode Cloud 시작](https://developer.apple.com/xcode-cloud/get-started/), [첫 workflow](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow), [Simulator·기기 실행](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices)
- 외부 무료 후보: [Render Free](https://render.com/docs/free), [Render compute](https://render.com/docs/compute-plans/), [Neon 가격](https://neon.com/pricing), [Supabase 가격](https://supabase.com/pricing)
- Spring: [Spring Boot system requirements](https://docs.spring.io/spring-boot/system-requirements.html)

# Money Snap 기술 스택 조사

> 상태 알림: 초기 후보 비교 자료다. Supabase 추천 결론은 2026-08-08 사용자의 Spring Boot·Cloudflare 결정으로 대체되었다. 현재 실행 가능성 근거는 `SPRING_CLOUDFLARE_RESEARCH.md`, 확정 결정은 `ADR.md`를 따른다.

> 조사 기준일: 2026-08-08
>
> 상태: 기술 결정을 위한 조사 자료. 이 문서 자체는 ADR이 아니며 기술 스택을 확정하지 않는다.

## 1. 제품 제약

기술 선택은 다음 제품 규칙을 우선해서 만족해야 한다.

- iPhone에서 사진, 금액, 카테고리를 빠르게 입력하고 오늘의 소비를 시각적 캔버스로 보여준다.
- 새 Snap은 항상 개인 기록으로 먼저 저장하고, 그룹 공유는 저장 이후 사용자가 명시적으로 선택한다.
- 금액 공개 여부는 그룹 단위 정책이다. 금액 비공개 그룹에는 가격 텍스트뿐 아니라 총액이나 금액에서 유도한 크기 차이도 노출하지 않는다.
- 공유된 Snap을 수정하거나 삭제하면 개인 캔버스와 그룹 표현에도 일관되게 반영되어야 한다.
- MVP에는 카드·계좌 연동, OCR, 공개 피드, 댓글·좋아요, 정산, 복잡한 통계가 포함되지 않는다.

근거는 [PRD](./PRD.md)와 [서비스 정책](./SERVICE_POLICY.md)이다. 따라서 기술 비교의 중심은 기능 수보다 사진 입력 경험, 개인 우선 저장, 그룹 인가, 금액 비공개 강제, 수정·삭제 일관성, 테스트 가능성이다.

## 2. 클라이언트 플랫폼 관련 공식 사실

### Native iOS

- Apple의 `PhotosPicker`는 사용자가 선택한 항목만 앱에 전달하는 개인정보 보호형 선택기를 제공하며, 일반적인 사진 보관함 전체 접근 권한 없이 사용할 수 있다. Apple은 큰 파일이나 여러 항목을 다룰 때 메모리 사용을 줄일 수 있는 파일 기반 표현도 안내한다. [Apple: 사진 선택기의 개인정보 모델](https://developer.apple.com/documentation/photokit/delivering-an-enhanced-privacy-experience-in-your-photos-app), [Apple: SwiftUI PhotosPicker](https://developer.apple.com/documentation/PhotoKit/bringing-photos-picker-to-your-swiftui-app)
- SwiftUI 안에서 `SpriteView`로 SpriteKit 장면을 표시할 수 있고, SpriteKit은 중력, 충돌, 회전, 감쇠를 지원한다. 이는 Money Snap의 낙하·충돌형 소비 캔버스 후보가 된다. [Apple: SpriteView](https://developer.apple.com/documentation/spritekit/spriteview), [Apple: SpriteKit 물리](https://developer.apple.com/documentation/spritekit/getting-started-with-physics)
- SwiftUI `Canvas`는 동적 2D 드로잉에 사용할 수 있지만, 그 안의 개별 요소에 대한 상호작용과 접근성을 직접 제공하지 않는다. Snap 각각을 선택하고 접근성 요소로 다뤄야 한다면 별도 설계가 필요하다. [Apple: Canvas](https://developer.apple.com/documentation/swiftui/canvas)

### 현재 Windows 작업 환경의 제약

- Apple의 Xcode 지원 표는 각 Xcode 버전을 설치할 수 있는 **macOS 버전**과 그 Xcode가 제공하는 iOS SDK·Simulator 범위를 명시한다. Apple은 앱을 Simulator 또는 실제 기기에서 실행하는 절차도 Xcode 기능으로 안내한다. [Apple: Xcode SDK 및 시스템 요구사항](https://developer.apple.com/xcode/system-requirements), [Apple: Simulator 또는 실제 기기에서 앱 실행](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices)
- 따라서 현재 Windows 작업 공간만으로는 Apple이 지원하는 Xcode 기반 native iOS 빌드와 iOS Simulator 검증을 직접 수행할 수 없다. 이는 앞의 공식 요구사항에서 도출한 결론이다. Native iOS를 선택하려면 지원되는 macOS/Xcode를 갖춘 로컬 Mac 또는 승인된 원격 macOS CI가 기술 게이트가 된다.

### Cross-platform 후보

- Flutter는 자체 위젯과 렌더링 계층을 사용한다. Apple 플랫폼 API 연동에는 플러그인 또는 비동기 platform channel을 사용하며, iOS platform view에는 문서화된 성능 제약이 있다. [Flutter: 아키텍처](https://docs.flutter.dev/resources/architectural-overview), [Flutter: 플랫폼 채널](https://docs.flutter.dev/platform-integration/platform-channels)
- React Native는 Swift/Objective-C 기능을 Native Module 또는 Native Component로 연결한다. New Architecture는 React Native 0.76부터 기본이며, 기존 라이브러리는 호환 계층을 사용하거나 포팅이 필요할 수 있다. [React Native: Native Platform](https://reactnative.dev/docs/native-platform), [React Native: New Architecture](https://reactnative.dev/architecture/landing-page)

Cross-platform 프레임워크를 선택해도 최종 iOS native 빌드와 Simulator 검증에 필요한 Apple 도구 체인 제약이 사라지는 것은 아니다. 다만 Windows에서 공유 UI·도메인 코드의 일부를 작성하고 테스트할 수 있는 범위는 넓어질 수 있다. 이 문장은 위 공식 플랫폼 구조와 Xcode 요구사항을 바탕으로 한 추론이다.

## 3. Supabase

### 공식 확인 사항

- 공식 `supabase-swift` SDK는 Swift Package Manager를 지원하며 Auth, PostgREST, Storage, Realtime 클라이언트를 제공한다. 조사 시점 저장소에 명시된 최소 요구사항은 iOS 13+, Xcode 15.3+, Swift 5.10+이다. [supabase-swift](https://github.com/supabase/supabase-swift)
- Supabase Auth는 JWT를 발급한다. 클라이언트의 데이터 접근은 JWT로 선택된 Postgres 역할과 Row Level Security(RLS) 정책을 결합해 행 단위로 제한할 수 있다. 공개용 키는 앱에 포함할 수 있지만 RLS를 우회하는 secret/service-role 키는 클라이언트에 두면 안 된다. [Supabase Auth](https://supabase.com/docs/guides/auth), [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [Supabase 데이터 보안](https://supabase.com/docs/guides/database/secure-data)
- Supabase Storage는 `storage.objects`에 RLS 정책을 적용한다. 정책을 만들지 않으면 업로드가 기본 거부된다. [Supabase Storage 접근 제어](https://supabase.com/docs/guides/storage/security/access-control)
- 표준 업로드는 작은 파일에 권장되며, 6MB를 초과하는 파일에는 TUS 기반 resumable upload가 권장된다. [Supabase Storage 업로드](https://supabase.com/docs/guides/storage/uploads/standard-uploads)
- 데이터베이스 백업에는 Storage 객체가 포함되지 않는다. 객체 삭제는 Storage API로 수행해야 하며 SQL로 메타데이터만 삭제하면 실제 파일이 남을 수 있다. [Supabase 데이터베이스 개요](https://supabase.com/docs/guides/database/overview), [Supabase 객체 삭제](https://supabase.com/docs/guides/storage/management/delete-objects)
- 프로젝트의 Postgres, Auth, Storage는 선택한 주 리전에 배치되며 서울 `ap-northeast-2` 리전이 제공된다. [Supabase 리전](https://supabase.com/docs/guides/platform/regions), [Supabase GDPR 및 데이터 위치](https://supabase.com/docs/guides/security/gdpr-compliance)
- CLI는 Docker 기반 로컬 스택을 제공한다. pgTAP을 포함한 테스트 도구로 스키마, 제약조건, RLS 허용·거부 동작을 검증할 수 있다. [Supabase 로컬 CLI](https://supabase.com/docs/guides/local-development/cli/getting-started), [Supabase 데이터베이스 테스트](https://supabase.com/docs/guides/local-development/testing/overview)
- 조사한 공식 문서 범위에서는 Firestore의 Apple 클라이언트처럼 기본 제공되는 영속 오프라인 동기화 계층을 확인하지 못했다. 이는 “지원하지 않는다”는 단정이 아니라, 오프라인 기록이 요구사항이면 별도 로컬 저장과 업로드 큐를 설계·검증해야 한다는 조사 경계다.

### Money Snap 적합성에 대한 해석

- 관계형 모델과 RLS는 `snap`, `group`, `group_membership`, `snap_share`처럼 관계와 무결성이 중요한 데이터에 자연스럽게 대응한다.
- Storage RLS와 데이터 RLS를 같은 사용자·그룹 경계에 맞춰 테스트할 수 있다.
- 반면 데이터베이스 행과 객체 파일의 저장·삭제는 하나의 원자적 트랜잭션으로 간주할 수 없다. 업로드 실패, Snap 저장 실패, 삭제 실패를 복구하는 상태와 정리 작업이 필요하다.
- 오프라인 우선 UX를 MVP 필수로 정한다면 Supabase 자체 기능으로 가정하지 말고 클라이언트 로컬 저장과 동기화 규칙을 별도 범위로 산정해야 한다.

## 4. Firebase

### 공식 확인 사항

- Firebase Apple SDK는 Swift Package Manager를 지원한다. 조사 시점 Firebase 12 계열은 iOS 15+를 대상으로 하며 공식 릴리스 노트는 최신 릴리스별 Xcode 요구사항을 명시한다. [Firebase Apple SDK 릴리스 노트](https://firebase.google.com/support/release-notes/ios), [firebase-ios-sdk](https://github.com/firebase/firebase-ios-sdk)
- Cloud Firestore는 테이블과 행이 아니라 컬렉션, 문서, 하위 컬렉션으로 구성되는 schemaless NoSQL 데이터베이스다. [Firestore 데이터 모델](https://firebase.google.com/docs/firestore/data-model)
- Apple 플랫폼에서는 Firestore 오프라인 persistence가 기본 활성화되며, SDK가 캐시 읽기·쓰기·쿼리와 재연결 후 동기화를 관리한다. [Firestore 오프라인 접근](https://firebase.google.com/docs/firestore/manage-data/enable-offline)
- 모바일 요청은 Firebase Auth와 Security Rules로 인가한다. Rules는 쿼리 결과를 사후 필터링하지 않으므로, 잠재 결과에 허용되지 않은 문서가 포함될 수 있는 쿼리는 전체 실패한다. [Firestore 안전한 쿼리](https://firebase.google.com/docs/firestore/security/rules-query)
- Rules에서 그룹 멤버십 문서를 `get()` 또는 `exists()`로 확인할 수 있지만, 규칙 평가에는 문서 접근 호출 수 제한이 있다. 이 종속 문서 읽기는 요청이 거부되어도 과금될 수 있다. [Firestore Rules 조건과 제한](https://firebase.google.com/docs/firestore/security/rules-conditions)
- Storage Rules는 Auth, 객체 경로·크기·MIME 유형과 Firestore 문서를 이용해 접근을 검사할 수 있다. Apple Storage SDK는 메모리 또는 로컬 파일 업로드, 진행률 관찰, 일시정지·재개·취소를 지원한다. [Firebase Storage Rules](https://firebase.google.com/docs/storage/security/rules-conditions), [Firebase Apple 파일 업로드](https://firebase.google.com/docs/storage/ios/upload-files)
- App Check는 Apple 플랫폼에서 DeviceCheck 또는 App Attest를 사용해 비공식 클라이언트의 백엔드 접근을 줄이는 보완 계층이며 사용자 인증을 대체하지 않는다. [Firebase App Check](https://firebase.google.com/docs/app-check)
- Firestore와 Storage는 서울 `asia-northeast3` 리전을 선택할 수 있다. Firebase Authentication의 처리 위치는 공식 개인정보 문서에서 별도로 확인해야 하며, 조사 결과에는 미국 데이터센터 처리로 명시되어 있다. [Firestore 리전](https://firebase.google.com/docs/firestore/locations), [Firebase 개인정보 및 데이터 처리 위치](https://firebase.google.com/support/privacy/)
- Emulator Suite와 Rules 단위 테스트 라이브러리로 인증 문맥을 모의하고 Firestore·Storage Rules의 허용·거부를 자동 검증할 수 있다. [Firebase Rules 단위 테스트](https://firebase.google.com/docs/rules/unit-tests)

### Money Snap 적합성에 대한 해석

- 오프라인 persistence와 재연결 동기화가 MVP의 최우선 요구사항이라면 세 후보 중 Firebase의 공식 클라이언트 지원이 가장 분명하다.
- 반면 그룹 멤버십, 원본 Snap, 다중 그룹 공유, 공개 정책을 문서 구조와 쿼리 규칙에 맞게 중복 설계해야 할 수 있다. Rules가 필터가 아니라는 성질과 접근 호출 제한을 초기 쿼리 설계부터 반영해야 한다.
- 데이터 정합성과 수정·삭제 전파를 문서 복제로 해결하면 구현은 빨라질 수 있지만, 복제된 데이터의 동기화 책임이 생긴다. 이는 Firestore 데이터 모델을 Money Snap 요구사항에 적용한 추론이다.

## 5. 자체 백엔드

### 공식 확인 사항

- PostgreSQL은 자체 백엔드에서도 RLS를 제공한다. RLS를 활성화하고 정책이 없으면 기본 거부되지만, superuser, `BYPASSRLS` 역할, 일반적으로 테이블 소유자는 정책을 우회한다. [PostgreSQL Row Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- S3 presigned URL은 특정 객체 작업을 제한 시간 동안 허용할 수 있지만 URL 자체가 bearer token으로 동작한다. 객체 키, HTTP 메서드, 만료, 체크섬을 제한하고 URL 노출을 방지해야 한다. [AWS S3 presigned URL](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html)
- Apple의 `URLSession`은 파일 기반 background transfer를 제공하며 시스템이 앱의 실행 상태와 별개로 전송을 관리할 수 있다. [Apple: Background transfer](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background), [Apple: URLSessionUploadTask](https://developer.apple.com/documentation/foundation/urlsessionuploadtask)

### Money Snap 적합성에 대한 해석

- 자체 API는 도메인 명령, 응답 투영, 권한 정책을 완전히 소유할 수 있어 금액 비공개 응답을 명시적으로 설계하기 쉽다.
- 그러나 Auth, 세션, 멤버십 인가, 마이그레이션, 업로드 서명, 삭제 복구, 모니터링, 운영 보안과 테스트 하네스를 모두 프로젝트가 책임진다.
- API가 테이블 소유자나 RLS 우회 권한으로 데이터베이스에 연결한다면 애플리케이션 인가 또는 `FORCE ROW LEVEL SECURITY` 등을 별도 방어 경계로 설계해야 한다.
- MVP 검증 속도보다 백엔드 완전 소유가 우선이라는 근거가 아직 없으므로, 지금 자체 백엔드를 선택하면 제품 검증 전에 운영 범위가 커진다.

## 6. 보안·개인정보 영향

### 금액 비공개는 UI 숨김이 아니다

- Firestore 읽기는 문서 단위다. Security Rules로 같은 문서의 일부 필드만 숨길 수 없으므로, 공식 문서는 민감 필드를 별도 문서로 분리하도록 안내한다. [Firestore 필드 접근 제어](https://firebase.google.com/docs/firestore/security/rules-fields)
- Supabase RLS는 행 단위 정책이며 열 제한은 별도 권한 체계다. 동적인 그룹 설정에 따라 같은 행의 금액 열만 숨기는 요구사항을 RLS 하나로 해결할 수 없다. [Supabase 열 수준 보안](https://supabase.com/docs/guides/database/postgres/column-level-security)

따라서 공급자와 관계없이 개인 원본과 그룹에 반환할 투영의 경계를 설계해야 한다. 가능한 방식은 금액이 없는 공유 데이터 구조를 별도로 두거나, 신뢰된 서버 경계가 그룹 정책에 맞는 응답만 생성하는 것이다. 어떤 방식을 선택하든 금액 비공개 응답에는 가격, 합계, 금액 비율, 금액 기반 정렬·크기 값을 포함하지 않아야 한다.

### 반드시 검증할 경계

- 소유자만 개인 Snap 원본을 읽고 수정·삭제할 수 있는가.
- 비회원과 탈퇴 회원이 그룹 데이터와 사진을 읽을 수 없는가.
- 그룹 멤버십 변경이 데이터베이스와 사진 접근에 즉시 반영되는가.
- 금액 비공개 그룹 응답에 금액 또는 금액에서 유도한 값이 직렬화되지 않는가.
- 사진 업로드 후 데이터 저장 실패, 데이터 삭제 후 객체 삭제 실패를 탐지하고 복구하는가.
- 사용자 탈퇴 시 개인 Snap, 공유 관계, Storage 객체를 빠짐없이 삭제하는가.
- 공개용 클라이언트 키와 관리자 권한 키를 분리하고 관리자 키가 앱·로그·번들에 포함되지 않는가.

이 항목들은 정상 경로 테스트뿐 아니라 소유자, 비회원, 탈퇴 회원, 공개 그룹, 비공개 그룹을 구분한 부정 권한 테스트로 고정해야 한다.

## 7. 비교

| 기준 | Supabase | Firebase | 자체 백엔드 |
|---|---|---|---|
| 핵심 데이터 모델 | PostgreSQL 관계형 모델 | Firestore 문서형 NoSQL | 선택한 DB와 API 모델을 직접 소유 |
| 그룹 관계·무결성 | FK, 제약조건, SQL, RLS와 잘 맞음 | 문서 구조와 Rules에 맞춘 중복·쿼리 설계 필요 | 가장 자유롭지만 전체 구현 책임 |
| Apple 기본 오프라인 동기화 | 조사 범위에서 Firestore 동등 기능을 확인하지 못함 | Apple SDK에서 기본 persistence 제공 | 직접 설계 |
| 금액 비공개 | RLS만으로 같은 행의 동적 열 숨김 불가 | Rules만으로 같은 문서의 일부 필드 숨김 불가 | 전용 API 투영으로 강제 가능 |
| 사진 접근 제어 | Storage RLS | Storage Rules | presigned URL과 서버 인가 직접 설계 |
| 로컬 권한 테스트 | Docker 로컬 스택 + pgTAP | Emulator Suite + Rules 테스트 | 테스트 환경 전체 구성 필요 |
| 서울 데이터 리전 | 프로젝트 리전 제공 | Firestore·Storage 리전 제공 | 선택한 인프라에 따라 결정 |
| 초기 MVP 속도 | 관계형 모델과 관리형 Auth·Storage의 균형 | 오프라인·클라이언트 중심 구현에 강점 | 가장 많은 기반 작업 필요 |
| 주요 위험 | 객체와 DB 생명주기, 별도 오프라인 설계 | Rules 쿼리 제약, 문서 중복과 금액 필드 분리 | 보안·운영·관측·복구 전부 직접 소유 |

클라이언트 선택은 백엔드와 별개 축이다.

| 기준 | SwiftUI + SpriteKit | Flutter | React Native |
|---|---|---|---|
| iPhone UX와 Apple API | Apple의 native UI·사진·물리 API를 직접 사용 | 플러그인·platform channel 경계 필요 | Native Module·Component 경계 필요 |
| 캔버스 후보 | SpriteKit 물리 기능을 직접 사용 가능 | 자체 렌더링 계층에서 구현 | JS/React 계층과 native/그래픽 라이브러리 조합 필요 |
| Android·웹 코드 공유 | 낮음 | 높음 | 높음 |
| 현재 Windows에서의 작업 범위 | Xcode build·Simulator 불가 | 공유 코드 작업은 가능하나 최종 iOS 검증은 macOS/Xcode 필요 | 공유 코드 작업은 가능하나 최종 iOS 검증은 macOS/Xcode 필요 |

## 8. 추론과 권고

현재 제품 범위만을 기준으로 한 1순위 가설은 다음과 같다.

1. **클라이언트: iPhone-first SwiftUI + SpriteKit**
   사진 선택과 낙하·충돌 캔버스가 핵심 차별점이므로 Apple의 native API를 직접 사용하는 이점이 크다. 단, 지원되는 Mac/Xcode 환경을 즉시 확보할 수 있을 때만 실행 가능한 선택이다.
2. **백엔드: Supabase의 PostgreSQL + Auth + private Storage**
   Snap 원본, 그룹 멤버십, 다중 그룹 공유 관계와 수정·삭제 일관성은 관계형 모델에 잘 맞는다. 관리형 Auth·Storage와 로컬 RLS 테스트를 사용해 MVP 기반 작업을 줄일 수 있다.
3. **권한 경계: 클라이언트 직접 테이블 노출만으로 끝내지 않기**
   개인 원본은 소유자 기준 RLS로 보호하고, 그룹 조회는 금액 공개 정책이 적용된 별도 데이터 구조 또는 신뢰된 서버 투영을 통해 반환한다. 비공개 그룹 응답 타입에는 금액 파생값 자체를 넣지 않는다.
4. **자체 백엔드: 보류**
   MVP로 핵심 경험을 검증한 뒤 BaaS 제약, 운영 요구 또는 비용이 실제로 나타날 때 다시 평가한다.

Firebase는 탈락안이 아니다. **네트워크 없이 기록하고 재연결 시 자동 동기화하는 경험이 MVP의 필수 AC로 확정된다면** Firebase를 다시 1순위로 비교해야 한다. 반대로 오프라인이 MVP 필수가 아니고 그룹 관계·금액 공개 정책의 명확성이 더 중요하면 현재는 Supabase 쪽 근거가 더 강하다.

플랫폼 역시 아직 확정할 수 없다. Mac/Xcode 확보가 어렵거나 Android·웹 동시 출시가 MVP 목표로 바뀐다면 SwiftUI 권고를 유지할 수 없으며 Flutter 또는 React Native를 동일한 사용자 흐름 프로토타입으로 비교해야 한다.

## 9. 미결정 사항

다음 결정이 내려지기 전에는 ADR과 구현 작업을 `ready`로 확정하지 않는다.

1. **출시 플랫폼**: iPhone 단독 MVP인지, Android·웹 동시 대상인지.
2. **macOS/Xcode 확보**: 로컬 Mac, 원격 macOS CI, 실제 iPhone 테스트 기기를 언제 확보할지.
3. **오프라인 수준**: 네트워크 없이 신규 Snap 저장이 필수인지, 실패 후 재시도 안내로 충분한지.
4. **인증 방식**: Sign in with Apple만 사용할지, 이메일 또는 다른 공급자를 함께 지원할지.
5. **화폐 범위**: MVP를 KRW 양의 정수로 고정할지, 다중 통화와 소수 단위를 고려할지.
6. **오늘의 기준**: 사용자 기기 시간대, 계정 시간대, 서버 시간대 중 무엇으로 날짜를 확정할지.
7. **사진 정책**: 허용 형식, 최대 원본 크기, 리사이즈·압축 기준, 업로드 재시도와 보관 기간.
8. **그룹 정책**: 그룹 생성·초대·가입·탈퇴 방식과 금액 공개 설정의 생성 후 변경 가능 여부.
9. **삭제 정책**: 계정 탈퇴, Snap 삭제, 공유 취소 시 데이터와 객체의 보존·복구·완전 삭제 시점.

## 10. 다음 기술 게이트

위 미결정 사항 중 플랫폼, macOS/Xcode, 오프라인 수준을 먼저 결정한다. 그 결과에 따라 작은 기술 검증을 수행한다.

- Native iOS 후보: `PhotosPicker → 개인 Snap 저장 → SpriteKit 캔버스 표시`를 실제 Xcode/Simulator 또는 기기에서 검증한다.
- Supabase 후보: 소유자, 그룹 회원, 비회원, 탈퇴 회원, 금액 공개·비공개 그룹을 포함한 RLS/Storage 부정 권한 테스트를 로컬 스택에서 먼저 작성한다.
- Firebase 재검토 조건: 오프라인 기록이 필수로 결정되면 동일한 사용자 흐름과 Rules 테스트로 비교한다.

검증 결과가 나온 뒤에만 [ADR](./ADR.md)에 선택, 이유, 포기한 대안을 기록하고 [아키텍처 문서](./ARCHITECTURE.md)를 구체화한다.

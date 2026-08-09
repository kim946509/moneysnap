---
id: WORK-013
status: done
depends_on: [WORK-012]
owner: codex
---

# 서버 identity session core

## Intent

검증된 Apple subject를 Money Snap 사용자와 연결하고 access·refresh token 회전, 재사용 탐지와 로그아웃을 PostgreSQL에서 안전하게 처리한다.

## In scope

- `IdentitySessionService` 로그인, 인증, refresh, 로그아웃 Interface
- 15분 access token과 180일 inactivity refresh session
- refresh token 1회 사용과 재사용 시 token family 폐기
- token 원문을 저장하지 않는 SHA-256 hash persistence
- users, apple identities, sessions, refresh tokens Flyway schema
- PostgreSQL 18 Testcontainers 통합 테스트

## Out of scope

- Apple identity token 검증과 authorization code 교환 Adapter
- HTTP controller와 bearer filter
- Apple token 암호화 저장·revoke와 계정 데이터 삭제
- iOS UI와 Keychain
- 배포

## Acceptance criteria

- [x] 같은 Apple subject는 같은 Money Snap user로 연결된다.
- [x] 로그인은 15분 access token과 180일 refresh token을 발급한다.
- [x] refresh는 두 token을 회전하고 이전 access token을 즉시 무효화한다.
- [x] 사용한 refresh token을 다시 제출하면 해당 session family 전체가 폐기된다.
- [x] 로그아웃 뒤 access·refresh token을 모두 사용할 수 없다.
- [x] DB에는 access·refresh token 원문이 저장되지 않는다.
- [x] 실제 PostgreSQL constraint와 transaction으로 위 동작을 검증한다.

## Test seam

- public seam: `IdentitySessionService.signIn`, `authenticate`, `refresh`, `logout`
- external Adapter seam: 검증을 마친 `VerifiedAppleIdentity`; 실제 Apple HTTP는 다음 작업이 소유한다.
- persistence seam: `IdentitySessionStore`; 완료 검증은 `JdbcIdentitySessionStore`를 Testcontainers PostgreSQL 18에 연결한다.

## Verification

```text
cd server; .\gradlew.bat test --no-daemon --console=plain
cd server; .\gradlew.bat bootJar --no-daemon --console=plain
```

## Evidence

- 실행 명령:
  - `cd server; .\gradlew.bat test --tests "*IdentitySessionServiceIntegrationTests" --no-daemon --console=plain`
  - `cd server; .\gradlew.bat test --no-daemon --console=plain`
  - `cd server; .\gradlew.bat bootJar --no-daemon --console=plain`
  - `git diff --check`
- 결과:
  - 로그아웃/access 회전 경쟁 테스트는 수정 전 7개 중 1개 실패했고, `sessionId` 폐기로 변경한 뒤 통과했다.
  - 활성 refresh token 단일성 테스트는 index 추가 전 실패했고, PostgreSQL partial unique index 추가 뒤 통과했다.
  - identity PostgreSQL 18 Testcontainers 통합 테스트 13개 통과.
  - 최종 서버 전체 테스트 24개 통과, failure 0, error 0 (`BUILD SUCCESSFUL in 52s`).
  - 최종 production JAR 생성 통과 (`BUILD SUCCESSFUL in 15s`).
- 리뷰:
  - Standards: 복합 테스트를 단일 책임으로 분리하고, persistence 원문 비저장은 합의한 persistence seam의 보안 contract test로 명확히 분리했다.
  - Ponytail: 미사용 `token_family`, 범위 밖 Apple refresh-token 컬럼, `IssuedTokens` wrapper와 단일 구현 `TokenHasher` interface를 제거했다.
  - Spec: 로그아웃/refresh 경쟁, 만료 경계, inactivity 연장, rotation rollback, 동시 refresh 재사용, DB active-token constraint 공백을 테스트와 구현으로 해소했다.

## Agent rules impact

- 영향 여부: no
- 근거: WORK-012에서 확정한 identity/session 불변 규칙과 기존 package-by-feature·Testcontainers 절차 안의 구현이다.
- 처리 결과: 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: incremental update 완료
- base: `d6e3306`
- risk: medium (`0.60`)
- findings와 처리 결과:
  - 그래프는 Java/JUnit 호출 연결을 인식하지 못해 service method 45개 test gap을 보고했으나, 해당 public seam은 PostgreSQL 18 통합 테스트 13개와 전체 테스트 24개로 직접 검증했다.
  - 독립 Standards/Spec 리뷰의 actionable finding은 모두 수정하고 테스트 후 그래프를 다시 증분 update했다.

## Decisions and risks

- token은 32-byte CSPRNG opaque value이며 DB에는 SHA-256 hash만 둔다.
- session row 자체를 refresh-token family로 사용하며 별도 `token_family` 식별자는 두지 않는다.
- session당 `ACTIVE` refresh token은 PostgreSQL partial unique index로 하나만 허용한다.
- refresh token은 한 번만 사용할 수 있고 reuse는 도난 가능성으로 취급한다.
- 로그아웃은 회전 가능한 access hash가 아니라 인증 시 확인한 불변 session ID로 폐기한다.
- Apple 검증·revoke가 아직 없으므로 이 작업만으로 로그인 HTTP 기능이 활성화되지는 않는다.

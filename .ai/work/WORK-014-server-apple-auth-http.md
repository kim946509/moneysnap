---
id: WORK-014
status: done
depends_on: [WORK-013]
owner: codex
---

# 서버 Apple 인증 HTTP 경계

## Intent

Apple credential을 공식 검증·교환한 뒤 Money Snap session을 발급하고 HTTP bearer 인증, refresh, 현재 session 로그아웃까지 연결한다.

## In scope

- `POST /api/v1/auth/apple`, `POST /api/v1/auth/refresh`, `POST /api/v1/auth/logout`
- Apple identity token의 signature, issuer, audience, expiry, nonce 검증
- single-use authorization code의 Apple token endpoint 교환과 subject 일치 확인
- Apple refresh token AES-256-GCM 암호화 저장
- ES256 Apple client secret 생성
- access bearer filter와 stateless Spring Security 설정
- HTTP/Apple Adapter/암호화/실제 PostgreSQL persistence 테스트

## Out of scope

- 계정 탈퇴와 Apple revoke
- Apple server-to-server event
- iOS AuthenticationServices와 Keychain UI
- Apple Developer portal의 explicit App ID/key 활성화
- 배포

## Acceptance criteria

- [x] 유효한 Apple credential과 code는 15분 access token, 180일 refresh token을 반환한다.
- [x] Apple signature·issuer·audience·expiry·nonce 또는 code 교환이 잘못되면 Money Snap session을 만들지 않고 401을 반환한다.
- [x] 교환 전후 identity token의 Apple subject가 다르면 401을 반환한다.
- [x] refresh는 token pair를 회전하고 이전 token을 무효화한다.
- [x] bearer access token으로 보호 route의 actor를 복구한다.
- [x] 로그아웃은 현재 session만 폐기하고 이후 access·refresh를 거부한다.
- [x] Apple refresh token은 AES-256-GCM ciphertext로만 PostgreSQL에 저장한다.
- [x] private key, client secret, Apple/Money Snap token 원문을 로그나 저장소에 남기지 않는다.

## Test seam

- HTTP seam: 세 auth endpoint와 bearer filter를 MockMvc로 검증한다.
- Apple Adapter seam: local signed JWT와 가짜 token endpoint로 official claim·exchange 계약을 검증한다.
- persistence seam: `IdentitySessionService` 로그인 결과와 암호화된 Apple refresh token을 PostgreSQL 18 Testcontainers로 검증한다.

## Verification

```text
cd server; .\gradlew.bat test --no-daemon --console=plain
cd server; .\gradlew.bat bootJar --no-daemon --console=plain
git diff --check
```

## Evidence

- 실행 명령: `cd server; .\gradlew.bat test --no-daemon --console=plain`
- 결과: `BUILD SUCCESSFUL`, 47 tests, failures 0, errors 0. PostgreSQL 18 Testcontainers로 signed JWT → fake Apple HTTP → AES-GCM → persistence와 HTTP session 전 경로를 검증했다.
- 실행 명령: `cd server; .\gradlew.bat bootJar --no-daemon --console=plain`
- 결과: `BUILD SUCCESSFUL`, `moneysnap-server.jar` 생성.
- 실행 명령: `git diff --check`, `git diff --cached --check`
- 결과: 모두 exit 0.
- 리뷰: Standards 재리뷰 hard violation 0건, Spec 재리뷰 누락·범위 이탈 0건. 초기 finding의 자명한 암호화 테스트, 이전 token·무부작용·actor 증거 공백, Apple 4xx 공백을 모두 수정했다.

## Agent rules impact

- 영향 여부: yes
- 근거: 서버 Apple 로그인·session HTTP 경계가 완료되어 `AGENTS.md`의 현재 단계와 다음 인증 작업 설명이 바뀐다.
- 처리 결과: 기준 문서 `docs/DEVELOPMENT_PLAN.md`를 먼저 갱신하고 `AGENTS.md`를 계정 탈퇴·Apple revoke/event와 iOS 연결이 다음 단계인 상태로 동기화했다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: incremental update 완료
- base: `0cece42`
- risk: medium (`0.60`)
- graph state: 370 nodes, 3140 edges, 66 files. 새 파일을 staging한 뒤 full rebuild 없이 증분 update했다.
- findings와 처리 결과: 그래프가 우선 검토 대상으로 제시한 Apple adapter, security filter/controller, cipher와 persistence 경로를 실제 통합·단위 테스트 및 양축 리뷰로 확인했다. 구조적 test gap 74건은 package-private test 연결을 인식하지 못한 휴리스틱 결과이며 해당 변경 경로는 47개 통과 테스트로 검증됐다.

## Decisions and risks

- Apple authorization code는 5분 single-use이며 반드시 token endpoint에서 교환한다.
- JWKS key rotation은 Spring Security Nimbus decoder의 `kid` 기반 조회에 맡긴다.
- Apple client secret은 고정 파일로 저장하지 않고 runtime `.p8` key에서 요청 시 생성한다.
- 외부 Apple 활성화 전에는 local contract test까지만 완료할 수 있다.

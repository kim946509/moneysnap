---
id: WORK-016
status: done
depends_on: [WORK-015]
owner: codex
---

# Apple 서버 간 계정 이벤트 처리

## Intent

Apple이 서명해 전송한 계정 상태 이벤트를 재전송에도 안전하게 처리해 승인 철회 시 모든 session을 폐기하고 Apple 계정 삭제 시 Money Snap 계정 데이터를 삭제한다.

## In scope

- 익명 접근 가능한 `POST /api/v1/auth/apple/events`
- Apple JWS의 RS256 signature, issuer, audience, issued-at, event id·type·subject·time 검증
- `jti` 기반 원자적 중복 방지와 재전송 200 응답
- `consent-revoked`의 모든 Money Snap session 폐기
- `account-deleted`의 사용자와 연결 데이터 삭제
- 이메일을 저장하지 않는 현재 모델에서 `email-enabled`, `email-disabled`의 검증·중복 기록 후 무효과 처리
- PostgreSQL 18 Testcontainers와 HTTP 통합 테스트

## Out of scope

- Apple Developer portal callback URL 활성화와 실제 Apple 전송 검증
- 이메일 저장 또는 사용자 알림
- 앱 내 탈퇴 시 Apple token revoke 흐름 변경
- iOS AuthenticationServices·Keychain UI

## Acceptance criteria

- [x] 유효한 `consent-revoked` JWS는 200이고 해당 Apple identity의 모든 access·refresh session을 거부하지만 사용자 데이터를 유지한다.
- [x] 유효한 `account-deleted` JWS는 200이고 해당 사용자·identity·session·연결 데이터를 삭제한다.
- [x] 같은 `jti`의 재전송은 200이며 부수 효과를 한 번만 적용한다.
- [x] 유효한 `email-enabled`, `email-disabled` JWS는 200이고 현재 제품 데이터에는 부수 효과가 없다.
- [x] 잘못된 signature·issuer·audience, 미래 `iat`, 누락되거나 잘못된 event claim은 401이고 DB를 변경하지 않는다.
- [x] 알 수 없는 event type은 검증된 요청이라도 400으로 거부하고 receipt를 저장하지 않는다.
- [x] event endpoint는 bearer 없이 접근 가능하고 다른 `/api/v1/**` 인증 규칙은 유지한다.

## Test seam

- verifier seam: 로컬 RSA key로 서명한 JWS를 Nimbus decoder에 전달해 claim·서명 경계를 먼저 실패시킨다.
- persistence seam: PostgreSQL 18 Testcontainers에서 receipt 원자성, 전체 session 폐기와 user cascade를 먼저 실패시킨다.
- HTTP seam: event verifier를 외부 경계로 교체한 MockMvc 테스트로 익명 200/400/401과 application service 연결을 먼저 실패시킨다.

## Verification

```text
cd server; .\gradlew.bat test --no-daemon --console=plain
cd server; .\gradlew.bat bootJar --no-daemon --console=plain
git diff --check
```

## Evidence

- 실행 명령: `cd server; .\gradlew.bat test --no-daemon --console=plain`
- 결과: `BUILD SUCCESSFUL`, 87 tests, failures 0, errors 0. PostgreSQL 18 Testcontainers로 모든 session 폐기, account cascade, sequential·concurrent `jti` 중복 방지와 email no-op를 검증했다.
- 실행 명령: `cd server; .\gradlew.bat bootJar --no-daemon --console=plain`
- 결과: `BUILD SUCCESSFUL`, production JAR 생성.
- 실행 명령: `git diff --check`, `git diff --cached --check`
- 결과: 모두 exit 0.
- 리뷰: Standards 재리뷰 hard violation 0건, Spec 재리뷰 누락·scope creep 0건. 명시적 wire-to-enum test, fractional `event_time` 거부, HTTP 단일 주장, 불필요한 store 반환값을 보강·정리했다.

## Agent rules impact

- 영향 여부: yes
- 근거: Apple server-to-server event 완료 시 다음 인증 단계와 현재 구현 상태가 바뀐다.
- 처리 결과: `docs/SERVICE_POLICY.md`, `docs/ARCHITECTURE.md`, `docs/DEVELOPMENT_PLAN.md`를 먼저 갱신하고 `AGENTS.md` 현재 단계를 server event 완료·다음 iOS로 동기화했다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: incremental update 완료
- base: `0380997`
- risk: medium (`0.60`)
- graph state: 534 nodes, 4662 edges, 79 files. staged 새 파일을 포함해 full rebuild 없이 증분 update했다.
- findings와 처리 결과: 우선 검토 대상인 JWS unauthorized 경계, user 삭제와 전체 session revoke를 verifier·HTTP·PostgreSQL 테스트와 양축 리뷰로 확인했다. 구조적 test gap 55건은 package-private test 연결을 인식하지 못한 휴리스틱 결과이며 관련 경로는 87개 전체 테스트로 검증됐다.

## Decisions and risks

- event 이름과 envelope은 Apple 공식 문서의 `consent-revoked`, `account-deleted`, `email-enabled`, `email-disabled`와 `{ "payload": "<JWS>" }` 계약을 따른다.
- `iat`은 서버 현재 시각보다 5분을 초과해 미래이면 거부한다. Apple event에는 expiration claim이 없으므로 오래된 정상 이벤트를 임의 만료시키지 않고 `jti` receipt로 재전송을 제어한다.
- receipt는 탈퇴 후에도 같은 event 재전송을 식별해야 하므로 user FK나 Apple subject를 저장하지 않는다.

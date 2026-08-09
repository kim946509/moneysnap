---
id: WORK-012
status: complete
depends_on: [WORK-010]
owner: codex
---

# Apple 인증·계정 정책과 알림 MVP 범위 확정

## Intent

Sign in with Apple 단독 인증의 세션·로그아웃·계정 탈퇴 계약을 고정하고 알림을 MVP에서 제외해 다음 구현 단계의 경계를 명확히 한다.

## In scope

- Sign in with Apple 단독 로그인과 Money Snap 세션 유지 정책
- 로그아웃, Apple 연결 해제, 계정 탈퇴의 서로 다른 효과
- Apple server-to-server account event 처리 원칙
- 알림의 MVP 제외 결정
- 제품·흐름·아키텍처·개발 계획·에이전트 계약 동기화

## Out of scope

- 서버 또는 iOS 인증 코드 구현
- Apple App ID, key, certificate, App Store Connect 변경
- 로컬 알림 또는 APNs 구현
- 배포

## Acceptance criteria

- [x] Apple 이외의 로그인 방식이 MVP 범위에 없다고 명시된다.
- [x] 로그인 유지, 로그아웃, 탈퇴와 Apple account event의 효과가 구분된다.
- [x] 계정 탈퇴가 앱 안에서 재인증·데이터 삭제·Apple token revoke를 수행한다고 명시된다.
- [x] 알림이 MVP 제외 범위와 개발 계획에 반영된다.
- [x] 다음 인증 기능의 테스트 경계와 외부 Apple activation 게이트가 드러난다.

## Test seam

- 문서 기준점이므로 코드 테스트 seam은 없다. 다음 기능은 서버 `IdentitySession` application Interface와 iOS `AuthenticationClient`를 public seam으로 사용한다.

## Verification

```text
git diff --check
rg -n "Sign in with Apple|알림|180일|계정 탈퇴" docs CONTEXT.md AGENTS.md .ai/work/WORK-012-auth-account-policy.md
```

## Evidence

- 실행 명령: `git diff --check`
- 결과: exit 0
- 실행 명령: `rg -n "Sign in with Apple|알림|180일|계정 탈퇴" docs CONTEXT.md AGENTS.md .ai/work/WORK-012-auth-account-policy.md`
- 결과: PRD, 서비스 정책, 사용자 흐름, 화면 구조, UI, 아키텍처, ADR, 개발 계획과 에이전트 계약에서 결정 확인
- 리뷰: 알림은 코드 변경 없이 MVP 제외로 닫고, 다음 인증 기능의 public test seam을 고정했다.

## Agent rules impact

- 영향 여부: yes
- 근거: 인증 provider, 세션 보안 불변 규칙, 알림 MVP 범위와 다음 단계가 바뀐다.
- 처리 결과: `AGENTS.md` 갱신

## Code Review Graph

- 코드 변경 여부: no
- graph action: skipped
- base: `39f73bf`
- risk: low
- findings와 처리 결과: 문서만 변경하므로 생략한다.

## Decisions and risks

- 알림은 하루 2회 고정안도 포함해 MVP에서 제외한다.
- Money Snap refresh session은 Keychain에 저장하고 사용 중 180일 inactivity window를 갱신한다.
- 실제 Apple 로그인과 token revoke 검증은 explicit App ID와 Apple key activation이 필요하다.

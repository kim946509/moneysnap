---
id: WORK-059
status: in_progress
depends_on: []
owner: codex
---

# Apple 로그인 진단 및 TestFlight 배포

## Intent

Apple 로그인 실패를 진단할 수 있도록 설정과 안전한 로그를 보완하고 승인된 TestFlight 배포를 진행한다.

## In scope

- Xcode Sign in with Apple capability 메타데이터 명시
- 인증 단계와 HTTP 상태/숫자 오류 코드만 기록
- 한국어 테스트 설명과 CI 검증 후 TestFlight 배포

## Out of scope

- 서버 변경, 인증 검증 완화, UI 변경

## Acceptance criteria

- [x] 기존 entitlement와 일치하는 capability 설정
- [x] 로그에 토큰, 자격증명, 응답 본문, 임의 오류 설명을 포함하지 않음
- [ ] iOS CI 통과
- [ ] TestFlight 업로드 및 테스트 설명 등록 확인
- [ ] 실제 기기 Apple 로그인 성공 확인

## Test seam

기존 인증 API/세션 테스트와 iOS CI. 실제 Apple 계정 인증은 기기 테스트가 필요하다.

## Verification

```text
git diff --check
xcodebuild -list -project ios/MoneySnap.xcodeproj
```

## Evidence

- 설정/로깅 변경이며 실제 로그인 실패의 원인 확정 또는 해결 완료로 주장하지 않는다.
- 기존 로컬 빌드는 iOS 플랫폼 부재로 실행 불가. CI 결과를 배포 게이트로 사용한다.
- 공개 localizedDescription 로그를 제거하고 숫자 오류 코드로 대체했다.

## Agent rules impact

- 영향 여부: no
- 근거: 기존 인증/배포 규칙을 변경하지 않는다.
- 처리 결과: AGENTS.md 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
- base: a2fb8ed230a4d1839d47c13f3b68c81517a13ccb
- risk: 인증 로깅의 개인정보 노출 및 iOS 빌드 호환성
- findings와 처리 결과: 그래프 도구가 현재 제공되지 않아 diff 직접 리뷰. 임의 오류 설명의 공개 로깅 제거.

## Decisions and risks

- Ponytail 스킬은 현재 제공되지 않음. 새 의존성 없이 OSLog와 기존 인증 흐름을 사용한다.
- capability 메타데이터 보완만으로 실제 로그인 성공을 보장하지 않는다. 프로비저닝 및 서버 상태 확인이 필요할 수 있다.
- ios/release-notes/ko.txt는 등록할 설명 원문이며 파일 작성 자체가 App Store Connect 등록을 의미하지 않는다.

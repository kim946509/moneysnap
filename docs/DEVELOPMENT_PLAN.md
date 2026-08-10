# Money Snap 기능 개발 계획

## 진행 원칙

- 한 단계는 사용자에게 보이는 하나의 동작과 그 동작을 지지하는 서버·iOS 경계를 함께 완성한다.
- 각 단계는 작업 항목 작성 → 실패 테스트 → 최소 구현 → 전체 회귀 테스트 → 393x852 시각 검수 → Code Review Graph → 커밋 순서로 닫는다.
- 매 단계마다 서버를 배포하지 않는다. `main`에 합칠 준비가 된 통합 묶음에서만 development CD를 사용한다.
- 인증, 사진 quota, 그룹 정책처럼 기준 문서에서 미결정인 내용은 결정을 받기 전 구현하지 않는다.
- Figma의 고정 frame과 reference screenshot이 UI 완료 판정의 기준이다.

## 단계

| 단계 | 사용자 가치 | 서버 범위 | iOS 범위 | 완료 게이트 | 상태 |
|---|---|---|---|---|---|
| 1. Today Snap 홈 읽기 기반 | 오늘의 Snap과 총 소비를 한눈에 본다 | 금액·카테고리·일별 합계 도메인 규칙 | Figma `9:2` 홈, fixture client, 로딩 상태 | 서버 단위 테스트, iOS 통합 테스트, 393x852 diff | complete (`WORK-010`) |
| 2. 인증 기반 | 자신의 기록만 안전하게 다룬다 | Apple credential 검증, rotating session, 로그아웃·탈퇴 | 로그인·Keychain 세션 복구·계정 관리 | 권한·token reuse·탈퇴 테스트, 로그인 화면 diff | active: 서버 인증·계정 이벤트 완료 (`WORK-013`~`WORK-016`), iOS 진행 전 |
| 3. 개인 Snap 저장 | 사진 선택 후 카테고리·금액을 저장한다 | idempotent record command, Flyway schema | PhotosUI, 단계 입력, 저장 완료 | Testcontainers 통합 테스트, 앱 흐름 테스트, 화면별 diff | blocked: 인증·사진 quota·시간대 |
| 4. 오늘 기록 조회 | 저장한 Snap이 Home에 반영된다 | owner/date 조회 API | URLSession adapter, 새로고침·오류·빈 상태 | 서버 API 통합 테스트, 실제 contract 통합 테스트 | depends on 3 |
| 5. 수정·삭제 | 내 기록을 고치거나 지운다 | revise/delete command와 소유권 검사 | 상세, 수정, 삭제 확인 | 권한·멱등성·회귀 테스트, 화면 diff | depends on 4 |
| 6. 사진 업로드 | 사진을 private 저장소에 안전하게 보관한다 | R2 presigned PUT/GET grant | 업로드·재시도·표시 | 최소 권한 R2 자격증명, 만료·권한 테스트 | depends on 2, 3 |
| 7. 그룹 기반 | 그룹을 만들고 멤버를 관리한다 | group·membership 모델 | 그룹 목록·상세 | 생성·초대·설정 정책 결정과 권한 테스트 | blocked: 그룹 정책 |
| 8. 그룹 공유 | 저장된 Snap을 그룹에 공유한다 | 별도 share command, 금액 공개 정책 | 저장 후 공유 진입·공유 완료 | 비공개 응답 누출 테스트, 화면 diff | depends on 5, 7 |
| 9. 보관함·마이 | 과거 기록과 기본 설정을 확인한다 | 기간 조회·사용자 요약 | 보관함·프로필 | pagination·빈 상태·화면 diff | depends on 4 |
| 10. MVP 통합 안정화 | 전체 핵심 흐름을 신뢰하고 사용한다 | 회귀·관측성·호환 migration | 전체 사용자 흐름·접근성·성능 | 전 구간 통합 테스트, visual suite, 승인된 development 배포 | depends on 1-9 |

## 현재 작업

- `WORK-010`: 정책 독립적인 Today Snap 홈 읽기 기반과 Figma 시각 회귀 임계값을 완료했다.
- `WORK-012`: Sign in with Apple 단독 인증·지속 session·로그아웃·탈퇴 정책을 확정하고 알림을 MVP에서 제외한다.
- `WORK-013`, `WORK-014`: 서버의 rotating session과 Apple credential 검증·교환·암호화 저장·HTTP bearer 로그아웃 경계를 완료했다.
- `WORK-015`: Apple 재인증·authorization revoke·모든 session과 계정 데이터 cascade 삭제를 완료했다.
- `WORK-016`: Apple server-to-server event의 JWS 검증, 중복 방지, session 폐기와 계정 삭제를 완료했다.
- 다음 단계는 iOS AuthenticationServices·Keychain 흐름을 연결한다.

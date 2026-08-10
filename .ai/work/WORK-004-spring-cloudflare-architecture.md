---
id: WORK-004
status: done
depends_on: [WORK-003]
owner: codex
---

# Spring Boot·Cloudflare 기반 iOS MVP 기술 설계 재수립

## Intent

사용자가 확정한 iOS 전용, Spring Boot 백엔드, Figma 고정 디자인, Cloudflare 사용 조건을 만족하면서 소규모 MVP를 무료에 가깝게 운영할 수 있는 실행 가능한 기술 계획을 확정한다.

## In scope

- Cloudflare Workers, Containers, R2, D1, Tunnel과 무료 플랜의 현재 제약 조사
- Windows와 macOS/Xcode 빌드·서명 경계 확인
- 실제 Figma 화면 노드와 구현 정합성 검증 방식 확인
- Cloudflare 직접 배포, 무료 하이브리드, Tunnel 기반 폐쇄형 MVP 대안 비교
- 최신 사용자 결정에 맞춘 PRD, ADR, 아키텍처, 기술 제안, UI 가이드와 `AGENTS.md` 동기화
- 무료 한도 보호와 유료 전환 승인 경계 설계

## Out of scope

- iOS 또는 Spring Boot 프로젝트 생성과 애플리케이션 코드 구현
- Cloudflare, Apple 또는 외부 데이터베이스 계정·리소스 생성과 배포
- DNS 변경, 도메인 연결, 결제 플랜 변경 또는 비용 발생 작업
- Figma 파일 수정과 디자인 범위 변경
- 미결정 제품 정책의 임의 확장

## Acceptance criteria

- [x] Spring Boot와 Cloudflare 런타임의 호환성 및 무료 운영 가능 범위가 공식 근거로 명확하다.
- [x] 최소 세 가지 배포 대안이 비용, 운영성, 보안과 이전 가능성 기준으로 비교된다.
- [x] iOS·Spring Boot·Cloudflare·Figma 관련 확정 결정과 보류 결정을 구분해 ADR에 기록한다.
- [x] Figma 실제 화면 노드와 픽셀 정합성 검증 루프가 문서화된다.
- [x] 무료 한도 초과 및 유료 전환은 사전 승인 없이는 발생하지 않도록 운영 경계가 정의된다.
- [x] 최신 기준 문서와 `AGENTS.md` 사이에 기술 스택·현재 단계 충돌이 없다.

## Test seam

- 공식 자료의 런타임·요금 사실과 프로젝트 권고를 분리하고, 기준 문서의 결정·보류 상태가 서로 일치하는지 검증한다.

## Verification

```text
git diff --check
PowerShell Test-Path와 Select-String 기반 필수 결정·경로·Figma 링크 검증
기준 문서와 AGENTS.md의 기술 스택·현재 단계 수동 대조
```

## Evidence

- 실행 명령: Cloudflare 공식 docs 검색으로 Workers 언어·제한, Containers GA·가격, R2/D1/Tunnel·billing alert를 확인했다.
- 실행 명령: Figma design context에서 홈 `9:2`, 그룹 상세 `77:163`, 금액 입력 완료 `153:4156`과 root metadata의 핵심 frame 목록을 확인했다.
- 실행 명령: Apple·Spring·Render·Neon 공식 자료를 조사해 `docs/SPRING_CLOUDFLARE_RESEARCH.md`에 사실·추론·권고를 분리했다.
- 실행 명령: `git diff --check`, PowerShell `Test-Path`·`Select-String`, `rg` template placeholder 검사를 실행했다.
- 결과: 모든 필수 문서와 결정 pattern이 존재하고 template placeholder가 없으며 `git diff --check`가 exit 0으로 통과했다. 출력에는 기존 LF→CRLF 경고만 있다.
- 결과: `docs/PRD.md`, `docs/UI_GUIDE.md`, `docs/ADR.md`, `docs/ARCHITECTURE.md`, `docs/TECHNICAL_DESIGN_PROPOSAL.md`, `docs/README.md`, `AGENTS.md`가 최신 결정과 일치한다.
- 리뷰: Spring Boot + Cloudflare 관리형 compute + 월 0원은 현재 불가능하다. 폐쇄형 TestFlight는 named Tunnel + private R2를 사용하고 public 단계에서 Containers의 월 최소 5 USD 또는 다른 JVM origin을 별도 승인하는 staged architecture가 범위·비용·이전성을 가장 잘 만족한다.

## Agent rules impact

- 영향 여부: yes
- 근거: 기술 스택, 아키텍처 원칙, 현재 프로젝트 단계와 구현 전제 조건이 바뀐다.
- 처리 결과: `AGENTS.md` 갱신 완료

## Code Review Graph

- 코드 변경 여부: no
- graph action: skipped
- base: `HEAD`
- risk: low
- findings와 처리 결과: 설계·문서 전용 작업이며 애플리케이션 소스와 테스트는 변경하지 않는다. 최초 소스 생성 작업에서 그래프가 없으면 full build한다.

## Decisions and risks

- 사용자 확정: MVP는 iOS 전용이며 백엔드는 Spring Boot를 사용한다.
- 사용자 확정: Cloudflare를 사용하고 소규모 MVP에서는 무료 운영을 우선한다.
- 사용자 확정: 지정된 Figma 파일을 구현의 시각적 기준으로 삼고 높은 화면 정합성을 요구한다.
- 결정: 표준 Workers에는 JVM이 없고 Containers는 GA지만 Workers Paid 전용이며 월 최소 5 USD다.
- 결정: 무료 폐쇄형 MVP는 named Tunnel 뒤의 stateless Spring Boot origin과 private R2로 시작한다.
- 결정: Windows는 source·project 파일 작성에 사용하고 Xcode·Simulator·서명·archive·pixel verification은 macOS lane에서 수행한다.
- 남은 게이트: interactive Mac 접근, closed MVP PostgreSQL 위치, Sign in with Apple 정책, 사진 quota, minimum iOS와 snapshot device/OS를 scaffold 전에 확정한다.

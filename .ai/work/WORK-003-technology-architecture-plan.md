---
id: WORK-003
status: done
depends_on: [WORK-002]
owner: codex
---

# MVP 기술 스택과 아키텍처 계획

## Intent

Money Snap MVP의 제품 범위를 지키면서 빠르게 검증하고 이후 확장 가능한 기술 스택과 핵심 module·seam을 근거와 함께 제안한다.

## In scope

- 공식 1차 문서 기반 모바일 클라이언트·백엔드·데이터·이미지·인증·테스트 기술 비교
- 네이티브 iOS 우선안과 대안 비교
- 최소 인터페이스, 확장성, 기본 사용자 흐름 최적화 관점의 아키텍처 대안 설계
- 추천 기술 스택과 단계별 도입 계획
- 사용자 결정이 필요한 기술 게이트 명시

## Out of scope

- 기술 스택 최종 확정과 ADR 승인 상태 변경
- 애플리케이션 프로젝트 생성 또는 코드 구현
- 외부 서비스 프로젝트 생성, 결제 또는 배포
- PRD 범위와 미결정 제품 정책의 임의 확장

## Acceptance criteria

- [x] 기술 후보 비교가 공식 1차 출처에 연결된다.
- [x] 최소 세 가지 구조 대안을 depth, locality, seam placement로 비교한다.
- [x] MVP 추천안과 채택·보류 기술이 명확하다.
- [x] 데이터·사진·인증·공유 권한·캔버스·테스트 전략이 포함된다.
- [x] 확정 전 사용자 결정이 필요한 질문이 분리된다.
- [x] 결과가 저장소 Markdown 문서로 남는다.

## Test seam

- 기술 선택의 각 요구사항이 PRD·정책과 대응하는지, 문서의 링크와 내부 경로가 유효한지 검토한다.

## Verification

```text
git diff --check
PowerShell Test-Path와 Select-String 기반 필수 섹션 검증
공식 출처 링크 검토
```

## Evidence

- 실행: 공식 Apple, Supabase, Firebase, PostgreSQL, AWS, Flutter, React Native 문서 조사
- 실행: 세 가지 대안의 병렬 Interface 설계와 depth·locality·seam placement 비교
- 실행: PowerShell `Test-Path`, `Select-String`, trailing whitespace 검사와 `git diff --check`
- 결과: `docs/TECH_STACK_RESEARCH.md`와 `docs/TECHNICAL_DESIGN_PROPOSAL.md` 작성 완료
- 결과: 필수 섹션, 내부 경로, 공식 1차 출처 도메인과 공백 검사가 모두 통과했다. `git diff --check`는 오류 없이 기존 LF→CRLF 경고만 출력했다.
- 리뷰: 네이티브 iOS + 자체 백엔드는 통제력 대비 MVP 비용이 크고, Expo + Supabase는 다중 플랫폼에는 유리하나 현재 iPhone UX에 불필요한 Adapter가 늘어난다. SwiftUI/SpriteKit + Supabase와 세 개 핵심 동작을 가진 `SnapLoop`가 현재 범위에서 가장 깊고 작은 설계다.

## Agent rules impact

- 영향 여부: no
- 근거: 기술 스택은 아직 proposed 상태이며, 현재 `AGENTS.md`의 기술 스택 미정 상태가 정확하다. 사용자 승인 후 별도 작업에서 `AGENTS.md`, `docs/ADR.md`, `docs/ARCHITECTURE.md`를 함께 갱신해야 한다.
- 처리 결과: 갱신 불필요

## Code Review Graph

- 코드 변경 여부: no
- graph action: skipped
- base: `HEAD`
- risk: low
- findings와 처리 결과: 기술 조사·설계 문서 작업이므로 코드 그래프 분석 생략

## Decisions and risks

- 현재 제품 문서의 iPhone UI와 iOS 확장 계획을 근거로 iOS-first를 기본 가정하되, Android 동시 출시 필요 여부를 결정 질문으로 남긴다.
- 관리형 백엔드의 속도와 공급자 종속성, 커스텀 백엔드의 통제력과 운영 비용을 함께 비교한다.

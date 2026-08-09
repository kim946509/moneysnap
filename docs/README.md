# Docs Guide

`docs/`는 하네스의 기준 문서 묶음입니다. Codex가 코드를 작성하기 전에 읽을 프로젝트 맥락을 여기에 둡니다.

범용 AI 환경의 구성, 루프, 그래프와 다른 프로젝트 적용 방법은 `AI_ENVIRONMENT.md`를 먼저 확인합니다.

## 작성 순서

1. `PRD.md`: 만들 것과 만들지 않을 것을 먼저 정한다.
2. `ARCHITECTURE.md`: 디렉토리 구조, 데이터 흐름, API 경계를 정한다.
3. `ADR.md`: 기술 선택의 이유와 트레이드오프를 기록한다.
4. `UI_GUIDE.md`: UI가 필요한 프로젝트라면 시각 기준과 금지 패턴을 구체화한다.

기술 스택의 후보 비교는 `TECH_STACK_RESEARCH.md`, Spring Boot·Cloudflare·iOS 실행 가능성은 `SPRING_CLOUDFLARE_RESEARCH.md`, CI/CD 공식 조사는 `CI_CD_RESEARCH.md`, 실제 자동화 운영 계약은 `CI_CD.md`, 현재 계획은 `TECHNICAL_DESIGN_PROPOSAL.md`에서 확인한다. 확정 결정은 `ADR.md`와 `ARCHITECTURE.md`가 소유한다.

## 좋은 문서 기준

- 판단 가능한 문장으로 쓴다.
- 파일 경로, 함수 이름, API 경계를 구체적으로 적는다.
- “조심한다” 대신 “무엇을 하지 않는다. 이유는 무엇이다”로 쓴다.
- MVP 제외 사항을 반드시 적는다.
- 기술 선택에는 트레이드오프를 남긴다.

## 각 문서 역할

| 파일 | 역할 | 핵심 질문 |
|------|------|-----------|
| `PRD.md` | 제품 요구사항 | 무엇을 만들고 무엇을 만들지 않는가? |
| `ARCHITECTURE.md` | 구현 구조 | 어디에 무엇을 두고 데이터는 어떻게 흐르는가? |
| `ADR.md` | 기술 결정 기록 | 왜 이 선택을 했고 무엇을 포기했는가? |
| `UI_GUIDE.md` | UI 품질 기준 | 어떤 화면 품질을 원하고 어떤 패턴을 피하는가? |
| `AI_ENVIRONMENT.md` | AI 개발 환경 | 에이전트가 어떤 계약과 루프로 일하는가? |
| `TECH_STACK_RESEARCH.md` | 기술 조사 | 공식 문서에서 확인된 사실과 후보별 제약은 무엇인가? |
| `SPRING_CLOUDFLARE_RESEARCH.md` | 실행 가능성 조사 | Spring Boot, Cloudflare 무료 계층, Windows/Xcode 경계는 무엇인가? |
| `TECHNICAL_DESIGN_PROPOSAL.md` | 기술 설계 제안 | MVP에 어떤 조합을 왜 추천하며 무엇이 아직 미결정인가? |
| `CI_CD_RESEARCH.md` | CI/CD 공식 조사 | GitHub, Apple, Cloudflare의 현재 제약과 근거는 무엇인가? |
| `CI_CD.md` | 자동화 운영 계약 | 어떤 revision을 어디서 검증·배포하고 secret·rollback을 어떻게 다루는가? |

## 보강 타이밍

- Codex가 범위를 넓히면 `PRD.md`의 MVP 제외 사항을 보강한다.
- 코드 위치가 흔들리면 `ARCHITECTURE.md`의 디렉토리 구조와 API 경계를 보강한다.
- 다른 라이브러리로 바꾸자는 제안이 반복되면 `ADR.md`에 트레이드오프를 추가한다.
- 화면이 평범하거나 템플릿처럼 보이면 `UI_GUIDE.md`의 색상, 컴포넌트, 금지 패턴을 구체화한다.

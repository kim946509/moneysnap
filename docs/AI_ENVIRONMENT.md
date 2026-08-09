# AI 개발 환경

## 목적

이 환경은 특정 모델이나 IDE에 종속되지 않고, 프로젝트 안에 규칙·상태·검증·스킬을 함께 저장해 AI 개발 작업을 반복 가능하게 만든다. 범용 코어만 구성하며 iOS 같은 플랫폼 확장은 별도 단계에서 추가한다.

## 구축 결과

```text
.
├── AGENTS.md                 # 모든 에이전트가 지킬 프로젝트 규칙
├── CONTEXT.md                # 프로젝트 공용 언어
├── .ai/
│   ├── README.md             # AI 작업 시작점
│   ├── harness.yaml          # 앵커·승인·상태 계약
│   ├── GRAPHS.md             # 작업 그래프와 개선 그래프
│   ├── LOOPS.md              # 반복 가능한 개발 루프
│   ├── skills.lock.json      # 설치 스킬 출처와 무결성
│   ├── templates/            # 작업·handoff·평가 템플릿
│   └── work/                 # 활성 작업 그래프
├── .agents/skills/           # 프로젝트 로컬 스킬
└── docs/                     # 제품·아키텍처·AI 환경 문서
```

기존 `.codex` 명령·훅과 `scripts/execute.py` 기반 자동 실행기는 제거했다. 모델이 상태를 직접 완료 처리하고 sandbox를 우회하던 실행 대신, Codex의 기본 승인·샌드박스 위에 선언형 계약과 결정론적 검증을 둔다.

## 설치된 로컬 스킬

Matt Pocock의 engineering 스킬 중 범용 개발에 필요한 조합만 `.agents/skills/`에 설치했다.

| 스킬 | 역할 | 주 사용 루프 |
|---|---|---|
| `grill-with-docs` | 질문을 통해 요구사항과 문서를 정제 | 기획 |
| `domain-modeling` | 용어와 도메인 경계 정제 | 기획·설계 |
| `to-spec` | 대화를 구현 가능한 명세로 변환 | 명세 |
| `to-tickets` | 명세를 blocking edge가 있는 작업으로 분해 | 작업 그래프 |
| `implement` | 명세 기반 구현을 TDD와 리뷰로 연결 | 구현 |
| `tdd` | red-green-refactor 수직 슬라이스 | 구현·버그 수정 |
| `diagnosing-bugs` | 재현과 계측 중심의 진단 | 버그 수정 |
| `codebase-design` | 깊은 모듈과 테스트 가능한 경계 설계 | 설계·리팩터링 |
| `code-review` | 명세 충실도와 표준을 분리 검토 | 리뷰 |
| `research` | 1차 출처 기반 기술 조사 문서화 | 조사·ADR |
| `resolving-merge-conflicts` | 양쪽 변경 의도를 추적해 충돌 해결 | 통합 |
| `project-ai-bootstrap` | 이 범용 환경을 새 프로젝트에 초기화·감사 | 환경 관리 |

설치 출처와 로컬 파일 해시는 `.ai/skills.lock.json`에 기록한다. `setup-matt-pocock-skills`는 별도 설정 체계를 추가하므로 설치하지 않고 이 하네스에서 직접 역할을 연결했다.

사용자 명시 호출형 스킬인 `grill-with-docs`, `to-spec`, `to-tickets`, `implement`는 Claude 전용 frontmatter를 제거하고 Codex의 `agents/openai.yaml`에서 `allow_implicit_invocation: false`를 유지하도록 로컬 정규화했다.

## Codex 플러그인

Ponytail은 프로젝트 로컬 스킬이 아니라 Codex에서 호출하는 횡단 플러그인이다.

| 플러그인 | 호출 스킬 | 역할 | 적용 범위 |
|---|---|---|---|
| `plugin://ponytail@ponytail` | `ponytail:ponytail` | YAGNI, 기존 코드·표준 라이브러리·네이티브 기능 우선, 최소 변경 검증 | 코드·구조·의존성·하네스 변경 |

기본 intensity는 `full`이다. 작업 시작 전에 필요성, 기존 구현, 표준·네이티브 대체 가능성, 새 의존성·추상화 필요성을 확인한다. 단순화는 제품 범위, 보안, 입력 검증, 접근성, Acceptance Criteria와 테스트를 약화할 수 없다. Ponytail은 `.agents/skills/`에 복사하지 않으며 `.ai/skills.lock.json`에도 로컬 스킬로 기록하지 않는다.

## 하네스, 루프, 그래프의 경계

- **하네스**: 에이전트가 볼 문맥, 사용할 스킬, 변경 권한, 상태와 검증 방식을 제공한다.
- **루프 엔지니어링**: 한 종류의 작업을 trigger부터 검증·종료·memory까지 반복 가능한 계약으로 만든다.
- **그래프 엔지니어링**: 여러 루프가 서로 감시·제약하도록 연결하고 목표 소유자, 거부권, 실행 주기와 고정 앵커를 둔다.

작업 그래프와 개선 그래프는 분리한다. 작업 그래프는 무엇을 어떤 순서로 수행했는지 나타내고, 개선 그래프는 하네스가 실패 경험을 통해 어떻게 바뀔 수 있는지 통제한다.

## 운영 방법

### 새 기능

```text
기획·도메인 → 명세 → 작업 그래프 → TDD 구현 → 리뷰 → 통합 검증 → 문서 → 배포 승인
```

작업을 시작하기 전에 `.ai/templates/work-item.md`로 범위와 AC를 고정한다. 코드가 만들어진 뒤에는 테스트·린트·빌드처럼 저장소의 실제 명령을 실행하고 결과를 Evidence에 남긴다.

### Ponytail 단순성 게이트

기획·명세·설계·구현·리팩터링·리뷰 루프에서 `ponytail:ponytail`을 횡단 게이트로 사용한다. 요구사항을 이해한 뒤 “이것이 필요한가 → 이미 있는가 → 표준 라이브러리인가 → 플랫폼 기능인가 → 기존 의존성으로 가능한가 → 최소 변경은 무엇인가” 순서로 판단한다. 비자명한 변경에는 가장 작은 실행 가능한 검증을 남긴다. 비용·보안·정확성·접근성·실제 사용자 결과가 걸린 변경은 단순성을 이유로 생략하지 않는다.

### 하네스 개선

하네스는 작업 도중 자기 편의를 위해 수정하지 않는다. 동일 실패가 3회 이상 반복되었을 때 별도 작업으로 열고, 한 요소만 변경한 뒤 held-out 시나리오로 평가한다. 사용자 승인 후 유지하며 개선이 불명확하거나 회귀가 있으면 롤백한다.

사용자가 특정 하네스 개선을 명시적으로 요청한 경우에도 별도 작업 항목으로 열 수 있다. 이 경우 요청이 변경 승인의 근거가 되며, 범위·검증·롤백 가능성은 동일하게 기록한다.

### AGENTS.md 동기화

`AGENTS.md`는 제품 문서의 사본이나 작업 일지가 아니라 모든 에이전트가 먼저 읽는 실행 계약이다. 작업별 상태는 `.ai/work/`, 상세 제품 사실은 해당 `docs/` 문서와 `CONTEXT.md`, 기술 결정은 `docs/ADR.md`가 소유한다.

모든 작업 항목은 `Agent rules impact`에서 영향 여부와 근거를 기록한다. 기준 문서 경로, 불변 규칙, 승인 경계, 기술 스택, 아키텍처 원칙, 개발 절차 또는 실제 검증 명령이 바뀌면 소유 문서를 먼저 수정하고 같은 작업 안에서 `AGENTS.md`를 동기화한다. 문서 동기화 단계와 릴리스 준비 전에는 필수 경로 존재와 `git diff --check` 결과를 Evidence로 남긴다.

초기 운영에서는 자동 훅을 사용하지 않는다. 수동 검사가 실제 작업에서 반복적으로 유효하고 결정론적임이 확인되면, 별도 하네스 개선 작업과 사용자 승인을 거쳐 훅이나 CI 검사로 승격한다.

### Code Review Graph

`.code-review-graph` MCP는 코드가 생성된 뒤 리뷰 루프의 영향 분석 노드로 사용한다. 런타임 DB는 `.code-review-graph/`에 생성하며 Git에 커밋하지 않는다.

1. 항상 `get_minimal_context_tool`로 현재 그래프와 변경 위험도를 먼저 확인한다.
2. 그래프가 없거나 손상됐거나, 파싱 가능한 소스가 있는데 인덱스가 비어 있으면 `build_or_update_graph_tool(full_rebuild=true)`를 실행한다.
3. 유효한 그래프가 있으면 의미 있는 소스·테스트 변경 묶음 후 `full_rebuild=false`와 고정 리뷰 기준점으로 증분 update한다.
4. 코드 리뷰, 인수인계, 병합·릴리스 준비 전에는 그래프 최신성을 다시 확인한다.
5. update 후 minimal context를 다시 확인한다. 위험도가 낮으면 minimal, 중간·높으면 standard change detection으로 변경 함수·영향 흐름·테스트 공백을 탐지한다.
6. Matt Pocock `code-review`의 명세/표준 리뷰와 결과를 함께 사용한다.
7. actionable finding은 원 작업의 범위와 AC 안에서 TDD로 수정하고 테스트 후 그래프를 다시 update한다.
8. graph action, 기준점, 위험도와 finding 처리 결과를 작업 항목 Evidence에 남긴다.

주기는 시간 기반이 아니라 변경 이벤트 기반이다. 현재 사용자 전역 Codex 훅은 `Write|Edit|Bash` 이후 `code-review-graph update --skip-flows`를 실행하고, 세션 시작·재개 시 `code-review-graph status`를 확인한다. 장기 실행 `watch`는 같은 목적의 대안이므로 훅과 동시에 사용하지 않는다.

저장소에서 새로 확인된 워크플로와 실제 명령을 `AGENTS.md`에 반영하는 작업은 별도의 주간 문서 거버넌스 루프로 운영한다. 이 자동화는 제품 정책이나 고정 앵커를 변경하지 않고, 결과 diff를 검토한 뒤 채택한다.

2026-08-08에 초기 full build를 실행했다. 현재 저장소에는 구현 코드가 없어 결과는 `0 files / 0 nodes / 0 edges`이며, 첫 파싱 가능한 애플리케이션 소스가 추가되면 full build를 다시 수행한다.

## 범용 원본

이 프로젝트에서 검증한 범용 AI 환경은 [AI Engineering Kit](https://github.com/kim946509/ai-engineering-kit)으로 분리했다. 저장소는 현재 `project-ai-bootstrap` 스킬 하나를 제공하며, 생성 구조·설치 스킬·사용법은 같은 이름의 `examples/project-ai-bootstrap/`에서 설명한다. Code Review Graph 자동 갱신과 주간 `AGENTS.md` 유지보수 설정은 이 스킬의 선택적 extension으로 관리한다.

Money Snap은 이를 적용한 소비자 프로젝트이며, 이 문서는 Money Snap에서 실제 활성화된 규칙과 로컬 차이만 기록한다.

## 확장 원칙

- 스킬은 전역 설치보다 프로젝트 로컬 설치를 기본으로 한다.
- 코어 문서는 도구에 종속된 설정과 분리한다.
- 새 자동화는 먼저 수동 루프에서 검증한 뒤 결정론적 스크립트나 CI로 승격한다.
- 새 지표에는 카운터 지표와 외부 앵커를 함께 정의한다.
- 빠른 구현 루프가 제품 범위, 보안 또는 배포 정책을 변경할 수 없게 한다.

## 다음 단계

범용 환경이 실제 작업에서 검증된 뒤 iOS 확장을 설계한다. 그 단계에서 Build iOS Apps 플러그인의 SwiftUI 구조, Xcode build/test, Simulator 검증, 접근성, 성능, 메모리와 릴리스 루프를 연결한다.

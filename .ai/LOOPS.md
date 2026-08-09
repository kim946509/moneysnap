# 개발 루프 카탈로그

모든 루프는 `trigger → goal → inputs → actions → verification → stop → memory`를 명시한다.

## 1. 기획·도메인 루프

- Trigger: 새 프로젝트, 새 기능, 범위가 불명확한 요청
- Goal: 용어, 포함/제외 범위, 결정 질문을 문서로 고정
- Inputs: 사용자 목표, PRD, 정책, 기존 ADR
- Skills: `grill-with-docs`, `domain-modeling`, 필요 시 `research`
- Actions: 질문 → 충돌 확인 → 시나리오 점검 → 기준 문서 갱신
- Verification: 사용자가 범위와 미결정을 확인
- Stop: 구현 가능한 결정 또는 명시적 `blocked`
- Memory: `CONTEXT.md`, PRD, ADR

## 2. 명세·작업 그래프 루프

- Trigger: 구현할 목표와 정책이 확정됨
- Goal: 검증 가능한 명세와 의존성 그래프 생성
- Inputs: 기준 문서와 사용자 결정
- Skills: `to-spec`, `to-tickets`, `codebase-design`
- Actions: AC 작성 → 경계 결정 → 작은 수직 작업으로 분해 → blocking edge 표시
- Verification: 각 작업이 독립 검증 가능하고 숨은 범위가 없음
- Stop: 모든 작업이 `ready` 또는 결정 필요로 `blocked`
- Memory: `.ai/work/*.md`, ADR

## 3. 기능 구현 루프

- Trigger: `ready` 작업 항목 하나
- Goal: 한 개의 수직 슬라이스를 테스트 우선으로 완료
- Inputs: 작업 항목, 관련 코드, 아키텍처 규칙
- Skills: `implement`, `tdd`, 필요 시 `codebase-design`
- Actions: 실패 테스트 → 최소 구현 → 통과 → 작은 리팩터링 → 의미 있는 코드 변경 묶음이 끝나면 그래프 증분 update
- Verification: 작업 항목의 명령과 전체 회귀 검증, 최신 그래프 update 증거
- Stop: 증거가 기록된 `done`, 또는 사유가 기록된 `blocked`
- Memory: 코드, 테스트, 작업 항목의 Evidence

## 4. 버그 진단 루프

- Trigger: 재현 가능하거나 반복되는 결함·성능 저하
- Goal: 원인을 입증하고 회귀 테스트로 고정
- Inputs: 증상, 로그, 변경 이력, 관련 흐름
- Skills: `diagnosing-bugs`, `tdd`
- Actions: 재현 → 최소화 → 가설 → 계측 → 수정 → 회귀 테스트
- Verification: 수정 전 실패하고 수정 후 통과하는 재현 증거
- Stop: 원인과 회귀 테스트가 있는 `done`, 재현 불가 또는 외부 의존은 `blocked`
- Memory: 테스트, 진단 기록, 필요 시 ADR

## 5. 코드 리뷰 루프

- Trigger: 구현과 자동 검증이 완료됨
- Goal: 명세 충실도와 코드 품질을 독립적으로 확인
- Inputs: 고정 기준점 이후 diff, 원 명세, 저장소 규칙
- Frozen anchors: 원 명세, 제품 범위, AC, 테스트·보안 규칙
- Skills/tools: `code-review`; `code-review-graph`의 `get_minimal_context_tool`, `build_or_update_graph_tool`, `detect_changes_tool`, 필요 시 affected flows·impact radius
- Actions: 고정 리뷰 기준점 확인 → `get_minimal_context_tool` → 그래프 부재·손상·미인덱싱이면 full build, 아니면 증분 update → minimal context 재확인 → 위험도별 `detect_changes_tool` → 명세/표준 리뷰 → 영향·테스트 공백 확인 → finding을 범위 안에서 TDD 수정 → 테스트 → 그래프 재update → 재검토
- Cadence: 의미 있는 소스·테스트 변경 묶음 후 증분 update; 코드 리뷰·인수인계·병합·릴리스 준비 전 최신성 확인; 문서 전용 작업은 사유 기록 후 생략
- Verification: 작업 항목에 graph action·base·risk·finding 처리 결과가 있고 actionable finding이 해결되거나 근거 있게 기각됨
- Stop: 중대한 finding 없음
- Memory: 리뷰 결과, 작업 항목, 커밋하지 않는 `.code-review-graph/` 런타임 상태
- Owner/cadence: 구현 담당자가 update, 리뷰 관점이 최신성과 finding을 검증 / 코드 변경 묶음과 모든 리뷰 게이트

## 6. 문서 동기화 루프

- Trigger: 사용자 동작, API, 구조, 운영 방식이 변경됨
- Goal: 코드와 기준 문서의 불일치 제거
- Inputs: diff, 테스트, ADR, 사용자 흐름
- Skills: 필요 시 `research`
- Actions: 변경된 사실 식별 → 소유 문서 갱신 → `AGENTS.md` 영향 판단 → 필요한 요약·링크·명령 동기화 → 중복 제거
- Verification: 문서의 명령·경로·정책이 실제 상태와 일치하고, 작업 항목의 `Agent rules impact`와 Evidence가 채워짐
- Stop: 관련 문서가 최신이거나 변경 불필요 근거가 있음
- Memory: docs, ADR, `AGENTS.md`, 작업 항목 Evidence

## 7. 릴리스 루프

- Trigger: 릴리스 후보가 통합 검증을 통과함
- Goal: 승인된 버전을 안전하게 배포하고 복구 가능하게 기록
- Inputs: 릴리스 diff, 테스트, 운영 체크리스트
- Skills: 플랫폼별 배포 스킬은 확장 프로필에서 추가
- Actions: 빌드 → 테스트 → 보안·설정 확인 → 사용자 승인 → 배포 → smoke test
- Verification: 실제 배포 대상에서 health/smoke 확인
- Stop: 성공 또는 롤백이 완료된 실패
- Memory: 버전, 배포 증거, 롤백 결과

## 8. 하네스 개선 루프

- Trigger: 동일 유형 실패가 3회 이상 반복되거나 사용자가 명시적으로 개선을 요청함
- Goal: 고정 앵커를 유지하며 하네스 한 요소를 개선
- Inputs: 실패 기록, 비용·시간, held-out 평가
- Actions: 실패 분류 → 가설 → 한 파일/규칙/스킬 변경 → 재평가
- Verification: 기존 평가 회귀 없이 목표 평가 개선
- Stop: 사용자 승인 후 유지, 아니면 즉시 롤백
- Memory: `docs/AI_ENVIRONMENT.md`의 변경 기록과 평가 결과

## 9. Agent 규칙 동기화 루프

- Trigger: 기준 문서 경로, 불변 규칙, 승인 경계, 기술 스택, 아키텍처 원칙, 개발 절차 또는 검증 명령이 변경됨
- Goal: `AGENTS.md`를 짧고 정확한 프로젝트 실행 계약으로 유지
- Inputs: 변경 diff, 제품 기준 문서, ADR, 실제 실행해 확인한 명령, 작업 항목의 `Agent rules impact`
- Frozen anchors: 사용자의 최신 명시적 결정, 제품 범위, 보안·승인 경계
- Actions: 변경 사실의 소유 문서 확정 → 소유 문서 먼저 갱신 → `AGENTS.md`의 링크·요약·명령 비교 → 필요한 최소 변경 → 중복·단기 상태 제거
- Verification: 필수 경로 존재, `git diff --check`, 작업 항목에 영향 판단과 실행 증거 기록
- Stop: 동기화 완료 또는 갱신 불필요 근거가 기록된 `done`; 기준 충돌이나 승인 부재는 `blocked`
- Memory: `AGENTS.md`, 소유 기준 문서, `.ai/work/*.md`
- Owner/cadence: 해당 변경 담당자 / 모든 작업의 문서 동기화 단계와 릴리스 준비 전
- Automation gate: 수동 검사의 유효성과 결정성이 반복 확인된 뒤 별도 하네스 개선 작업과 사용자 승인으로만 훅·CI 승격

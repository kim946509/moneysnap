---
id: WORK-056
status: active
depends_on: []
owner: grok
---

# Snap 상세를 Mobbin 영수증·사진 상세 패턴으로 정리

## Intent

Snap 상세를 설정 Form이 아니라 사진 한 장과 금액이 주인공인 확인 화면으로 바꾼다. 참고는 Mobbin iOS latest의 영수증 상세와 사진 포스트 상세다.

## In scope

- SnapDetailView surface: 폴라로이드 히어로, 큰 금액, 좌측 카테고리 칩, 툴바 삭제
- 카테고리·금액 변경 시 명시적 저장 버튼 없이 commit
- 금액 키보드 dismiss
- 상세에서 그룹 공유 UI 제거 (정책: 공유는 Home action)
- UI_GUIDE에 Mobbin 보완 기준 갱신

## Out of scope

- Home physics
- 사진 교체
- 공유 그룹 변경
- macOS visual capture (Windows). CI native test가 검증

## Acceptance criteria

- [ ] 상세에 `snap.detail.save` 저장 버튼이 없다
- [ ] 카테고리 칩과 금액 확정은 revise를 호출한다
- [ ] 삭제는 툴바에서만 제공한다
- [ ] 상세에 그룹 공유 목록이 없다
- [ ] `powershell -File ios\scripts\validate-project.ps1` 통과

## Test seam

- `SnapDetailModelTests`: 카테고리 변경과 금액 확정이 명시적 save 없이 revise한다. 미변경 draft는 호출하지 않는다.

## Verification

```text
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
```

## Evidence

- 실행 명령: `powershell -ExecutionPolicy Bypass -File ios\scripts\test-validate-pbx-object-ids.ps1`
- 결과: PBX object ID validation regression probe: OK. `validate-project.ps1`의 visual baseline probe는 이 작업 이전부터 `reviewed manifest`에서 실패한다 (Windows CRLF 이슈). macOS native test는 CI lane.
- 참고: agent-reach Jina Reader로 Mobbin iOS latest와 Starbucks/Shake Shack 영수증 상세, Instagram/BeReal 사진 상세를 읽었다.

## Agent rules impact

- 영향 여부: yes
- 근거: UI_GUIDE의 Snap 상세 보완 기준이 21st.dev에서 Mobbin 영수증·사진 상세로 바뀐다.
- 처리 결과: `docs/UI_GUIDE.md`를 같은 작업에서 갱신한다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
- findings와 처리 결과: Windows 세션에서 code-review-graph MCP 없음.

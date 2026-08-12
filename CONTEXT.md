# Money Snap Shared Language

에이전트와 개발자가 같은 제품 용어를 쓰기 위한 프로젝트 사전이다. 정책의 최종 근거는 `docs/PRD.md`와 `docs/SERVICE_POLICY.md`다.

## 기록

**Snap**:
카테고리와 KRW 금액을 필수로 가지며 사진 한 장을 선택적으로 연결하는 하나의 소비 기록.
_Avoid_: 지출 행, 거래, 사진 묶음

**개인 Snap**:
소유자만 볼 수 있도록 먼저 저장된 Snap. 그룹 공유의 원본이다.
_Avoid_: 비공개 복제본

**공유 Snap**:
개인 Snap 자체를 복제하지 않고 특정 그룹에 보이도록 만든 공유 관계.
_Avoid_: 그룹 Snap 복사본

**사진 없는 Snap**:
사진 대신 category별 고정 icon과 color placeholder로 표현하는 Snap.
_Avoid_: 빈 Snap, 기본 가격 이미지

**localDay**:
Snap을 기록할 때 소유자의 제출 time zone으로 정한 뒤 바뀌지 않는 calendar day label.
_Avoid_: 서버 날짜, 조회 시 재계산한 날짜

**오늘의 소비 캔버스**:
한 `localDay`의 개인 Snap을 금액 비율에 따른 크기와 배치로 보여주는 Home 화면.
_Avoid_: 거래 목록, 통계 대시보드

## 그룹

**그룹**:
owner 한 명과 member가 선택한 공유 Snap을 함께 보는 작은 관계 단위.
_Avoid_: 공개 피드, 공동 계좌

**금액 공개 그룹**:
공유 Snap의 금액과 사람별 오늘 총액을 구성원에게 보여주는 그룹.
_Avoid_: 공개 그룹

**금액 비공개 그룹**:
금액과 금액을 추정하게 하는 크기·정렬 신호를 구성원에게 제공하지 않는 그룹.
_Avoid_: 익명 그룹

**그룹 초대**:
가입 전에 group name과 금액 공개 여부를 확인하고 제한된 기간 안에 membership을 만드는 owner 발급 자격.
_Avoid_: 친구 링크, 영구 링크

**대표 Snap**:
그룹 상세에서 한 member가 해당 날짜에 가장 최근 `sharedAt`으로 공유한 Snap을 사용하는 요약 오브젝트.
_Avoid_: 가장 비싼 Snap, 최신 개인 Snap

## 계정

**Money Snap session**:
Apple 인증 뒤 사용자가 Money Snap에 계속 로그인되어 있는 상태.
_Avoid_: Apple identity token, Apple session

**MoneySnap 사용자**:
Apple이 첫 로그인에서 유효한 이름을 제공하지 않았을 때 사용하는 고정 display name.
_Avoid_: 사용자 ID 접미사 이름

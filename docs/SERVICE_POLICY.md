# Money Snap 서비스 정책

## 목적

이 문서는 Money Snap의 기록, 공유, 금액 공개, 수정/삭제, 입력 방식에 대한 기본 정책을 정의한다. 정책의 목표는 기능을 많이 만드는 것이 아니라, 사용자가 고민 없이 빠르게 소비를 기록하고 필요한 경우에만 그룹에 공유할 수 있게 만드는 것이다.

Money Snap은 복잡한 가계부가 아니라 가볍게 쓰는 소셜 소비 기록 앱이다. 따라서 모든 정책은 **단순함, 기본 비공개, 선택 중심 입력**을 기준으로 판단한다.

## 기본 원칙

- 기본 저장은 항상 나만 보기다.
- 친구 공유는 그룹 공유와 같은 의미로 사용한다.
- 공유는 필수가 아니라 선택이다.
- 금액 공개 옵션은 그룹 단위로 공개와 비공개만 제공한다.
- 키보드 입력은 가능하면 가격 입력으로 제한한다.
- 사진, 카테고리, 그룹은 선택 방식으로 빠르게 처리한다.
- 사용자가 정책을 이해하기 위해 긴 설명을 읽게 만들지 않는다.
- 기능이 편의보다 복잡도를 크게 늘리면 MVP에서 제외한다.

## 기록 정책

소비 기록은 카메라, 앨범 또는 사진 없음 quick action에서 시작한다.

사용자는 홈의 오늘의 소비 캔버스에서 기록하기를 누른 뒤 사진을 촬영하거나 앨범에서 이미지를 선택하거나 사진 없이 기록한다. 이후 카테고리를 선택하고 가격을 입력하면 기록이 완료된다.

기록 과정에서 필수 입력은 다음으로 제한한다.

- 카테고리
- 가격

사진은 권장 입력이지만 필수 입력으로 강제하지 않는다. 이유: 사용자가 사진을 찍기 어려운 상황에서도 10초 안에 소비를 남길 수 있어야 한다.

가격은 `1...999,999,999 KRW` 범위의 양의 정수만 저장한다. 부동소수점, 0, 음수와 범위를 넘는 값은 허용하지 않는다.

상태 변경 command의 `clientMutationId`는 actor 범위의 `1...128`자 nonblank opaque string이다. 서버는 값의 내부 형식을 해석하거나 UUID로 제한하지 않고 멱등성 key로만 사용한다. iOS는 새 command를 만들 때 UUID 문자열을 생성하지만 commit 결과를 알 수 없는 retry에서는 같은 값을 유지한다. Snap·group·share command는 operation schema에 없는 owner, group, visibility, image 또는 임의 field를 거부한다.

사용자는 기록할 때 기기의 tzdb region time zone ID와 `localDay`를 보낸다. 서버는 자체 `Clock`의 현재 instant를 제출된 zone으로 변환해 current day 또는 직전 day인 경우만 허용한다. `UTC`는 허용하지만 `+09:00` 같은 numeric offset과 `KST`, `PST` 같은 short alias는 거부한다. 미래와 2일 이전 날짜도 저장하지 않는다. 저장된 `localDay`는 소유자가 기록한 calendar label이며 이후 수정하거나 그룹 공유 시 바꾸지 않는다.

카메라는 한 기록 세션에서 1장, 앨범은 최대 3장을 선택할 수 있다. 앨범에서 여러 이미지를 선택한 경우 각 이미지를 별도 Snap 후보로 보고, 현재 이미지의 카테고리와 가격을 입력해 개인 Snap으로 저장한 뒤 다음 이미지로 넘어간다. 한 Snap에는 active image를 최대 1개만 연결한다. 여러 이미지의 금액과 카테고리를 한 화면에서 동시에 편집하는 대량 입력표는 MVP에서 만들지 않는다.

개발 단계 3은 사진 없이 카테고리와 가격만으로 durable 개인 Snap을 저장하는 경로를 먼저 완성한다. camera adapter, PhotosUI, 이미지 정규화와 private R2 연결은 단계 6에서 함께 완성하며, 그전에는 저장할 수 없는 사진 preview를 production 흐름에 노출하지 않는다.

초기 MVP에서는 결제수단, 예산, 상세 메모, 위치, 태그, 영수증 정보 같은 입력을 필수로 요구하지 않는다. 이유: 기록 흐름이 길어지면 Money Snap의 핵심 가치인 가벼움이 깨진다.

## 사진 저장 정책

iOS는 사진 방향을 보정하고 EXIF를 포함한 불필요한 metadata를 제거한 JPEG로 정규화한다. 결과는 최대 변 `1600px` 이하이고 `2,097,152 bytes` 이하여야 한다. private bucket에는 정규화 조건을 통과해 활성화된 사진만 Snap과 연결한다.

upload grant를 요청할 때 client는 정확한 byte size, `image/jpeg`와 SHA-256 checksum을 제출한다. 서버는 transaction 안에서 다음 두 경계를 함께 검사하고 pending reservation을 만든다.

- 사용자별 최근 24시간의 completed upload와 아직 만료되지 않은 pending upload 합계는 신규 예약을 포함해 20건 이하여야 한다.
- bucket의 active bytes와 nonexpired pending reserved bytes, 신규 예약 bytes 합계는 `7,000,000,000 bytes` 이하여야 한다.

삭제는 최근 24시간 upload quota를 환급하지 않는다. 실제 object 삭제가 확인되기 전에는 active bytes에서 제외하지 않는다. 전체 storage guardrail에 도달하면 신규 upload grant만 차단하고 기존 사진 read·delete와 사진 없는 Snap 저장은 유지한다.

upload intent와 grant는 발급 시각부터 10분 뒤 만료한다. complete에 성공했지만 Snap에 연결되지 않은 `ACTIVE_UNLINKED` media는 `completedAt`부터 24시간 동안 같은 사용자의 draft 복구 대상으로 보존한다. 사용자가 명시적으로 draft를 폐기했거나 `completedAt + 24시간` 경계에 도달한 뒤에도 연결되지 않은 경우에만 orphan cleanup 대상이 된다. expired·failed pending reservation, complete 검증에 실패한 object, eligible orphan object와 삭제 실패는 bounded retry cleanup 대상으로 관리한다.

계정 탈퇴는 media row를 바로 cascade해 object key를 잃지 않는다. transaction 안에서 해당 사용자의 pending·active·linked media를 account와 독립된 cleanup job/tombstone으로 먼저 전환한 뒤 계정 데이터를 삭제하고, private object 삭제와 byte 회계를 bounded retry로 완료한다. 다른 사용자의 media는 건드리지 않는다.

direct PUT grant는 exact `Content-Length`, `Content-Type`과 checksum을 서명 경계에 결합하고 실제 R2 contract test로 변경·누락·초과 upload가 저장되지 않는지 검증해야 한다. R2와 사용 중인 SDK가 이 경계를 강제하지 못하면 unrestricted presigned PUT을 노출하지 않고 Spring Boot가 `2,097,153 bytes`에서 읽기를 중단하는 bounded stream으로 R2에 전달한다.

upload complete는 object metadata만 신뢰하지 않는다. 서버가 private object를 최대 `2,097,153 bytes`의 bounded stream으로 읽어 JPEG signature, dimension, 실제 byte size, checksum과 EXIF 제거를 다시 검증하고 일치할 때만 image를 활성화한다. 불일치 object는 Snap에 연결하지 않고 cleanup 대상으로 만든다.

## 인증과 계정 정책

MVP 로그인은 Sign in with Apple만 제공한다. iOS가 Apple 사용자 인증을 시작하고 서버가 Apple credential을 검증한 뒤 Money Snap 자체 세션을 발급한다. 다른 소셜 로그인, 이메일·비밀번호와 게스트 계정은 만들지 않는다.

로그인한 사용자는 매번 Apple 로그인을 반복하지 않는다. 짧은 access token과 회전하는 refresh session을 사용하며, refresh session은 iOS Keychain에 저장한다. 정상 사용 중에는 180일 inactivity window가 갱신되어 사실상 로그인 상태가 유지된다. Apple credential이 취소되거나 refresh session이 만료·폐기된 경우에만 다시 로그인한다.

로그아웃은 현재 기기의 Money Snap session과 Keychain credential만 지운다. Apple 계정의 앱 사용 승인을 자동으로 철회하거나 다른 기기의 session을 종료하지 않는다.

계정 탈퇴는 마이 화면에서 찾을 수 있어야 하며, 재인증과 명시적 확인 뒤 수행한다. 서버는 모든 Money Snap session을 폐기하고 개인·공유 데이터와 계정에 연결된 데이터를 삭제하며 Apple token revoke endpoint로 authorization을 철회한다. 성공 후 iOS는 Keychain과 로컬 개인 데이터를 지운다. 자동 복구를 전제로 한 soft delete로 탈퇴를 가장하지 않는다.

Apple의 `consent-revoked` event는 모든 Money Snap session을 폐기하지만 사용자 데이터를 자동 삭제하지 않는다. Apple의 `account-deleted` event는 계정과 관련 데이터를 삭제한다. 앱 안의 탈퇴와 Apple account event는 같은 로컬 계정 삭제 경계를 사용한다.

Apple이 첫 로그인에서 `fullName`을 제공하면 trim 후 1~30 grapheme cluster인 값만 profile display name으로 저장한다. Apple이 이름을 제공하지 않거나 값이 유효하지 않으면 `MoneySnap 사용자`를 사용한다. MVP에는 display name 편집과 profile 사진 업로드를 두지 않는다. 기본 avatar는 display name의 첫 grapheme를 사용할 수 있을 때 이를 표시하고, 그렇지 않으면 MoneySnap mark를 표시한다.

## 알림 정책

점심·저녁 기록 리마인더를 포함한 로컬 알림과 APNs 원격 푸시는 MVP에서 제외한다. 핵심 기록 루프의 실제 사용성을 확인한 뒤 별도 기능으로 권한 요청 시점, 빈도, 시간과 피로 방지 정책을 결정한다. 로그인이나 첫 실행에서 알림 권한을 요청하지 않는다.

## 그룹 생성·멤버 정책

그룹은 owner 1명과 member로만 구성하며 owner를 포함해 최대 20명이다. group name은 trim 후 1~30 grapheme cluster여야 한다. 이름은 식별자가 아니므로 같은 owner가 같은 이름의 서로 다른 그룹을 만들 수 있다.

owner는 member를 내보내거나 그룹을 삭제할 수 있다. member는 스스로 탈퇴할 수 있다. owner 양도 기능이 없는 MVP에서 owner는 그룹을 탈퇴하거나 제거될 수 없으며, 그룹을 끝내려면 삭제한다. 그룹 삭제·member 탈퇴·강제 제거는 membership과 share 관계만 삭제하고 각 사용자의 개인 Snap을 삭제하지 않는다.

owner가 계정을 탈퇴하면 소유한 그룹과 그 그룹의 share 관계를 자동 삭제한다. 이 그룹에 참여했던 다른 member의 개인 Snap은 보존된다. 탈퇴 owner의 개인 Snap은 그룹 삭제가 아니라 계정 데이터 cascade에서 삭제된다.

## 그룹 초대 정책

owner가 초대를 발급하면 서버는 CSPRNG로 최소 128-bit entropy의 원문을 만들고 한 번만 보여 준다. 서버에는 hash만 저장하며 원문을 log·analytics, URL path 또는 query에 남기지 않는다. 초대는 `issuedAt + 168시간`에 만료한다.

한 그룹에는 active 초대가 하나만 존재한다. owner가 초대를 폐기하거나 재발급하면 이전 초대는 즉시 무효가 된다. 인증된 사용자는 가입 확정 전에 group name과 amount visibility를 preview로 확인하고 초대 원문은 가입 `POST` body로만 제출한다.

expired·revoked 초대와 정원이 찬 그룹의 신규 가입은 거부한다. 기존 member가 같은 그룹 가입을 재시도하면 멱등 성공한다. 정원 검사와 membership insert는 하나의 DB transaction에서 원자적으로 처리한다. 같은 actor와 `clientMutationId`로 이미 성공한 join replay는 초대의 현재 만료·폐기 상태보다 먼저 기존 결과를 반환한다.

## 그룹 공유 정책

Money Snap에서 친구 공유는 그룹 공유를 의미한다.

카테고리와 가격 입력이 완료되면 소비는 바로 나만 보기로 저장된다. 사용자가 속한 그룹이 있더라도 등록 바텀시트 안에서 그룹 선택을 요구하지 않는다.

사용자는 저장 이후 Home의 명시적 share action을 눌렀을 때만 특정 그룹을 선택해 함께 저장한다. 한 번의 share command는 이미 저장된 Snap 1개를 group 1개에만 공유하며 record와 분리된 `clientMutationId`를 사용한다. 같은 Snap·group·mutation을 재시도하면 최초 성공을 반환하고 중복 share를 만들지 않는다. 여러 Snap이나 여러 group을 한 번에 선택하는 batch UI는 MVP에서 만들지 않는다.

그룹 공유는 다음 원칙을 따른다.

- 그룹 공유는 기록 흐름을 방해하지 않아야 한다.
- 그룹이 없는 사용자에게는 그룹 공유 단계를 보여주지 않는다.
- 그룹이 있는 사용자도 등록 흐름 안에서는 나만 보기 저장을 쉽게 끝낼 수 있어야 한다.
- 하나의 소비는 나만 보기로 저장할 수 있고, 선택한 그룹에도 함께 저장할 수 있다.
- 그룹 공유는 공개 피드나 전체 공개 공유를 의미하지 않는다.
- 선택한 그룹에 공유되는 소비는 해당 그룹의 금액 공개 설정을 따른다.
- 공유 제안을 건너뛰거나 sheet를 닫아도 개인 Snap은 유지된다.
- 공유 실패는 개인 저장을 rollback하지 않고 Home에서 같은 share 의도를 재시도할 수 있어야 한다.
- 여러 group에 공유하려면 사용자가 group마다 명시적 action을 반복한다.

## 금액 공개 정책

금액 공개 옵션은 단순하게 공개와 비공개만 제공하며, MVP에서는 그룹 단위 설정으로 둔다.

- 공개: 그룹에 소비 사진 또는 category placeholder, 카테고리, 가격이 함께 보인다.
- 비공개: 그룹에 소비 사진 또는 category placeholder와 카테고리는 보이지만 가격은 보이지 않는다.

금액 공개 여부는 owner가 그룹을 만들 때 결정하고 MVP에서는 변경하지 않는다. 생성 또는 그룹 참여 시점에 사용자가 "이 그룹은 가격까지 공유하는 그룹"인지, "무엇을 샀는지만 공유하는 그룹"인지 이해할 수 있어야 한다. amount visibility 변경 endpoint도 제공하지 않는다.

기록 흐름에서는 금액 공개 여부를 매번 묻지 않는다. 이유: 소비를 기록할 때마다 공개 여부를 선택하게 하면 사용자가 멈춰서 고민하게 되고, Money Snap의 핵심인 빠른 기록 흐름이 느려진다.

비공개 그룹에서는 정확한 가격 텍스트를 숨길 뿐 아니라, 사람별 총액을 직접 추정하게 만드는 표현도 피한다. 서버 response에는 amount, total, amount-derived size와 order field를 넣지 않는다. 사람별 대표 Snap 오브젝트를 총액 기준으로 크게 또는 작게 보여주지 않으며, 고정된 크기·순서 또는 금액과 무관한 Snap 개수 정도의 가벼운 신호만 사용할 수 있다.

사진 없는 공유 Snap은 category마다 고정된 icon과 color placeholder를 사용한다. category가 같으면 금액에 따라 placeholder 모양·크기·색을 바꾸지 않는다. 사람별 대표 Snap은 해당 날짜에 가장 최근 `sharedAt`인 공유 Snap을 사용하고, 그 Snap에 사진이 없으면 같은 category placeholder를 대표로 사용한다.

금액 범위 공개, 일부 공개, 친구별 공개, 친한 친구 공개, 기록별 예외 공개 같은 중간 단계는 MVP에서 제공하지 않는다. 이유: 옵션이 늘어나면 사용자가 기록 중 공유 설정을 해석해야 하고 서비스의 가벼움이 떨어진다.

금액 공개 설정 변경은 MVP 이후 별도 migration과 사용자 동의 정책이 정해질 때 다시 연다.

## 수정 및 삭제 정책

공유 후에도 소비 기록은 수정하거나 삭제할 수 있다.

수정과 삭제는 별도 관리 화면을 만들기보다 홈 하단의 소비 목록에서 Snap 상세로 진입해 처리한다. 이유: 사용자가 기록을 고치기 위해 복잡한 메뉴를 찾아가게 만들면 안 된다.

Snap 상세에서 수정 가능한 항목은 MVP 기준으로 다음 두 가지로 제한한다.

- 카테고리
- 가격

사진 교체, 공유 그룹 변경, 금액 공개 설정 변경은 Snap 상세에서 제공하지 않는다. 이유: Snap 상세가 기록 수정과 공유 설정을 모두 담당하면 사용자가 화면의 목적을 해석해야 하고, 사용 흐름이 복잡해진다.

삭제는 사용자가 직접 실행할 수 있어야 한다. 삭제된 소비는 오늘의 소비 캔버스와 공유된 그룹 화면에서 더 이상 보이지 않아야 한다.

## 입력 단순화 정책

Money Snap의 입력 UX는 선택 중심이어야 한다.

가격 입력을 제외하면 사용자가 키보드로 긴 텍스트를 입력해야 하는 상황을 만들지 않는다. 카테고리와 그룹은 버튼, 칩, 리스트 선택처럼 빠르게 고를 수 있는 방식이어야 한다.

라이브 기록은 사진 선택 다음 카테고리와 금액을 한 전체 화면에서 받는다. 긴 폼을 만들지 않고 카테고리 그리드와 금액 키패드만 둔다. visual CI는 Figma staged 카테고리/금액 시트를 유지한다.

사진이 있는 기록에서는 입력 화면 상단에 현재 사진 미리보기와 진행 상태를 보여준다. 여러 장을 선택한 경우에는 `1/3`처럼 현재 위치를 표시한다. 남은 사진이 있으면 금액 입력 액션을 `다음`, 마지막 사진이면 `완료`로 표시한다.

등록 도중 닫는 경우 아직 저장되지 않은 현재 Snap 후보의 입력만 취소한다. 앞에서 `다음`을 눌러 저장한 기록은 유지한다.

금액 공개 여부는 기록 흐름 안의 토글이 아니다. owner는 그룹 생성 화면에서 선택하고 참여자는 가입 확정 전에 읽기 전용으로 확인한다.

선택지는 적어야 한다. 사용자가 기록 도중 멈춰서 설정을 해석해야 한다면 잘못된 흐름이다.

## MVP 제외 정책

다음 기능은 초기 MVP에서 제외한다.

- 금액 범위 공개
- 기록별 금액 공개 예외 설정
- 친구별 세부 공개 설정
- 공개 피드
- 좋아요, 댓글, 랭킹 중심의 소셜 기능
- 정산, 송금, 공동 지출 관리
- 카드, 계좌, 결제 내역 자동 연동
- OCR 기반 영수증 자동 인식
- 사진 배경 제거 및 누끼 처리
- 공유용 이미지와 짧은 영상 생성
- 예산 추천과 복잡한 통계
- 로컬 기록 리마인더와 원격 푸시 알림

제외 이유는 모두 동일하다. Money Snap의 초기 목표는 재무 관리 기능을 확장하는 것이 아니라, 소비를 빠르게 기록하고 직관적으로 보고 선택적으로 공유하는 경험을 검증하는 것이다.

## 정책 판단 기준

새 기능이나 정책을 추가할 때는 다음 질문을 먼저 확인한다.

- 사용자가 더 빠르게 기록할 수 있는가?
- 선택지가 불필요하게 늘어나지 않는가?
- 기본 비공개 원칙을 해치지 않는가?
- 가격 입력 외에 키보드 입력을 늘리지 않는가?
- 오늘의 소비 캔버스와 그룹 공유 경험을 더 명확하게 만드는가?

위 질문에 답하기 어렵다면 MVP에 넣지 않는다.

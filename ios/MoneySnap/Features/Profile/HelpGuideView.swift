import SwiftUI

enum HelpTopic: String, CaseIterable, Identifiable, Sendable {
    case record
    case privacy
    case groups
    case archive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .record: "기록하기"
        case .privacy: "나만 보기와 공유"
        case .groups: "그룹"
        case .archive: "보관함"
        }
    }

    var body: String {
        switch self {
        case .record:
            "홈의 기록하기나 가운데 추가로 소비를 남깁니다. 카메라 화면에서 1장 촬영, 앨범 최대 3장, 또는 사진 없이 카테고리와 금액을 한 번에 입력합니다. 여러 장을 고르면 사진마다 별도 Snap이 됩니다."
        case .privacy:
            "저장은 항상 나만 보기로 먼저 끝납니다. 속한 그룹이 있을 때만 저장 후 한 Snap을 한 그룹에 공유할 수 있습니다. 건너뛰거나 실패해도 개인 기록은 그대로입니다."
        case .groups:
            "그룹은 이름과 금액 공개 여부를 만들 때 정합니다. 공개 여부는 나중에 바꿀 수 없습니다. 초대 코드로 가입하고, owner는 멤버 제거와 그룹 삭제를 할 수 있습니다."
        case .archive:
            "보관함에서 지난 달 달력을 보고, 기록이 있는 날을 골라 그날 Snap을 확인·수정·삭제합니다."
        }
    }
}

struct HelpGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(HelpTopic.allCases) { topic in
                VStack(alignment: .leading, spacing: 6) {
                    Text(topic.title)
                        .font(.moneySnap(size: 17, weight: .bold))
                        .foregroundStyle(MoneySnapVisualSystem.ink)
                    Text(topic.body)
                        .font(.moneySnap(size: 14, weight: .medium))
                        .foregroundStyle(MoneySnapVisualSystem.secondaryText)
                }
                .padding(.vertical, 6)
                .frame(minHeight: 44, alignment: .leading)
                .accessibilityIdentifier("help.topic.\(topic.rawValue)")
            }
            .listStyle(.plain)
            .navigationTitle("도움말")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                        .accessibilityIdentifier("help.close")
                }
            }
            .accessibilityIdentifier("screen.help")
        }
    }
}

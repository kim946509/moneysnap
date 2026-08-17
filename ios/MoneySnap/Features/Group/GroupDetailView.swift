import SwiftUI

struct GroupDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: GroupDetailModel
    @State private var joinCode = ""
    @State private var confirmsDelete = false
    var onMembershipChanged: () -> Void = {}

    init(
        group: MoneySnapGroup,
        client: any GroupClient,
        onMembershipChanged: @escaping () -> Void = {}
    ) {
        _model = State(initialValue: GroupDetailModel(group: group, client: client))
        self.onMembershipChanged = onMembershipChanged
    }

    var body: some View {
        List {
            Section(model.group.name) {
                Text(model.group.amountVisible ? "금액 공개 그룹" : "금액 비공개 그룹")
                    .accessibilityIdentifier("screen.group.detail")
            }
            Section("오늘") {
                if model.group.amountVisible {
                    ForEach(model.visibleMembers, id: \.userId) { member in
                        VStack(alignment: .leading) {
                            Text(member.displayName)
                            Text("오늘 \(member.snapCount)개 · \(member.totalAmountWon.wonText)")
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("group.today.member")
                    }
                } else {
                    ForEach(model.hiddenMembers, id: \.userId) { member in
                        VStack(alignment: .leading) {
                            Text(member.displayName)
                            Text("오늘 \(member.snapCount)개")
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("group.today.member")
                    }
                }
            }
            Section("멤버") {
                ForEach(model.members, id: \.userId) { member in
                    HStack {
                        Text(member.avatar)
                        Text(member.displayName)
                        Spacer()
                        Text(member.role == "owner" ? "owner" : "member")
                        if model.group.role == .owner, member.role != "owner" {
                            Button("제거", role: .destructive) {
                                Task { await model.remove(memberID: member.userId) }
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("group.member.remove")
                        }
                    }
                    .frame(minHeight: 44)
                }
            }
            if model.group.role == .owner {
                Section("초대") {
                    Button("초대 코드 만들기") {
                        Task { await model.issueInvite() }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    if let inviteCode = model.inviteCode {
                        Text(inviteCode)
                            .textSelection(.enabled)
                        Button("초대 취소") {
                            Task { await model.revokeInvite() }
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
                Section {
                    Button("그룹 삭제", role: .destructive) { confirmsDelete = true }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("group.delete")
                }
            } else {
                Section {
                    Button("그룹 나가기", role: .destructive) {
                        Task {
                            if await model.leave() {
                                onMembershipChanged()
                                dismiss()
                            }
                        }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            Section("초대 코드로 가입") {
                TextField("코드", text: $joinCode)
                Button("미리보기") {
                    Task { await model.previewInvite(code: joinCode) }
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("group.invite.preview")
            }
        }
        .navigationTitle(model.group.name)
        .task { await model.load() }
        .alert(
            "이 그룹에 가입할까요?",
            isPresented: Binding(
                get: { model.joinPreview != nil },
                set: { if !$0 { model.cancelJoin() } }
            )
        ) {
            Button("가입") {
                Task {
                    if await model.confirmJoin() != nil {
                        onMembershipChanged()
                    }
                }
            }
            Button("취소", role: .cancel) { model.cancelJoin() }
        } message: {
            if let preview = model.joinPreview {
                Text("\(preview.name) · \(preview.amountVisible ? "금액 공개" : "금액 비공개")")
            }
        }
        .confirmationDialog("그룹을 삭제할까요? 개인 Snap은 그대로 남습니다.", isPresented: $confirmsDelete) {
            Button("삭제", role: .destructive) {
                Task {
                    if await model.deleteGroup() {
                        onMembershipChanged()
                        dismiss()
                    }
                }
            }
            Button("취소", role: .cancel) {}
        }
    }
}

struct GroupMember: Decodable, Equatable, Sendable {
    let userId: UUID
    let displayName: String
    let avatar: String
    let role: String
}

struct GroupMemberList: Decodable {
    let members: [GroupMember]
}

struct IssuedInvite: Decodable {
    let code: String
    let expiresAt: Date
}

struct InvitePreview: Decodable, Equatable {
    let name: String
    let amountVisible: Bool
}

struct VisibleGroupToday: Decodable {
    let localDay: String
    let members: [VisibleMemberToday]
}

struct VisibleMemberToday: Decodable, Equatable {
    let userId: UUID
    let displayName: String
    let avatar: String
    let snapCount: Int
    let totalAmountWon: Int64
}

struct HiddenGroupToday: Decodable {
    let localDay: String
    let members: [HiddenMemberToday]
}

struct HiddenMemberToday: Decodable, Equatable {
    let userId: UUID
    let displayName: String
    let avatar: String
    let snapCount: Int
}

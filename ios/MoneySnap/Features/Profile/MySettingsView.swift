import SwiftUI

struct MySettingsView: View {
    let authentication: AuthenticationModel
    var summaryClient: (any AccountSummaryClient)? = nil
    var groupClient: any GroupClient = UnavailableGroupClient()

    @State private var presentedSheet: MySettingsSheet?
    @State private var summary: AccountSummary?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.white
                header(availableWidth: proxy.size.width)
                profileCard
                monthlySummary
                settingsRows
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .groups:
                NavigationStack {
                    GroupListView(client: groupClient)
                        .navigationTitle("내 그룹 관리")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("닫기") { presentedSheet = nil }
                            }
                        }
                }
            case .account:
                AccountSettingsView(authentication: authentication)
            case .help:
                HelpGuideView()
            }
        }
        .task { await loadSummary() }
    }

    private func header(availableWidth: CGFloat) -> some View {
        Group {
            VStack(alignment: .leading, spacing: -2) {
                Text("My")
                    .font(.moneySnap(size: 22, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                    .accessibilityIdentifier("screen.my")
                Text("내 기록과 설정")
                    .font(.moneySnap(size: 13, weight: .medium))
                    .foregroundStyle(MoneySnapVisualSystem.secondaryText)
            }
            .offset(x: 28, y: 7)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(MoneySnapVisualSystem.navy, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 12, y: 9)
                .accessibilityHidden(true)
                .position(x: availableWidth - 40, y: 34)
        }
    }

    private var profileCard: some View {
        HStack(spacing: 16) {
            Text("나")
                .font(.moneySnap(size: 12, weight: .bold))
                .foregroundStyle(MoneySnapVisualSystem.ink)
                .frame(width: 64, height: 64)
                .background(MoneySnapVisualSystem.profileAvatar, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(summary?.displayName ?? "MoneySnap 사용자")
                    .font(.moneySnap(size: 20, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                Text("오늘 Snap \(summary?.todaySnapCount ?? 0)개 · 그룹 \(summary?.groupCount ?? 0)개")
                    .font(.moneySnap(size: 13, weight: .medium))
                    .foregroundStyle(MoneySnapVisualSystem.profileSecondaryText)
                Text("기본 비공개")
                    .font(.moneySnap(size: 11, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.profileBadgeText)
                    .frame(width: 90, height: 24)
                    .background(MoneySnapVisualSystem.profileNeutralFill, in: Capsule())
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 19)
        .frame(width: 345, height: 112)
        .profileSurface(cornerRadius: 22)
        .offset(x: 24, y: 82)
    }

    private var monthlySummary: some View {
        Group {
            Text("이번 달")
                .font(.moneySnap(size: 17, weight: .bold))
                .foregroundStyle(MoneySnapVisualSystem.ink)
                .offset(x: 28, y: 230)

            HStack(spacing: 15) {
                statCard(label: "기록한 Snap", value: "\(summary?.monthSnapCount ?? 0)개")
                statCard(label: "공유 그룹", value: "\(summary?.groupCount ?? 0)개")
            }
            .offset(x: 24, y: 264)
        }
    }

    private var settingsRows: some View {
        VStack(spacing: 16) {
            Button {
                presentedSheet = .groups
            } label: {
                settingsRow(title: "내 그룹 관리", subtitle: "그룹과 초대 설정")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("my.groups")
            Button {
                authentication.clearIssue()
                presentedSheet = .account
            } label: {
                settingsRow(title: "앱 설정", subtitle: "접근성, 계정")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("my.settings")
            Button {
                presentedSheet = .help
            } label: {
                settingsRow(title: "도움말", subtitle: "Money Snap 사용 가이드")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("my.help")
        }
        .offset(x: 24, y: 396)
    }

    private func statCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.moneySnap(size: 13, weight: .medium))
                .foregroundStyle(MoneySnapVisualSystem.profileSecondaryText)
            Text(value)
                .font(.moneySnap(size: 28, weight: .black))
                .foregroundStyle(MoneySnapVisualSystem.ink)
        }
        .padding(.horizontal, 17)
        .frame(width: 165, height: 92, alignment: .leading)
        .profileSurface(cornerRadius: 18)
    }

    private func settingsRow(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.moneySnap(size: 15, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                Text(subtitle)
                    .font(.moneySnap(size: 12, weight: .medium))
                    .foregroundStyle(MoneySnapVisualSystem.profileSecondaryText)
            }
            Spacer()
            Text("열기")
                .font(.moneySnap(size: 13, weight: .bold))
                .foregroundStyle(MoneySnapVisualSystem.profileSecondaryText)
        }
        .padding(.horizontal, 17)
        .frame(width: 345, height: 64)
        .profileSurface(cornerRadius: 16)
    }

}

private enum MySettingsSheet: String, Identifiable {
    case groups
    case account
    case help

    var id: String { rawValue }
}

private extension MySettingsView {
    func loadSummary() async {
        let zone = TimeZone.current.identifier.contains("/") ? TimeZone.current.identifier : "UTC"
        summary = try? await summaryClient?.summary(timeZone: zone)
    }
}

private extension View {
    func profileSurface(cornerRadius: CGFloat) -> some View {
        background(.white, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(MoneySnapVisualSystem.profileBorder)
            }
    }
}

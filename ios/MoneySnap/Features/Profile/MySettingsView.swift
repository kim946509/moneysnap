import SwiftUI

struct MySettingsView: View {
    let authentication: AuthenticationModel

    @State private var presentsAccountSettings = false

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
        .sheet(isPresented: $presentsAccountSettings) {
            AccountSettingsView(authentication: authentication)
        }
    }

    private func header(availableWidth: CGFloat) -> some View {
        Group {
            VStack(alignment: .leading, spacing: -2) {
                Text("My")
                    .font(.moneySnap(size: 22, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
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
                .background(Color(red: 1, green: 211.0 / 255, blue: 220.0 / 255), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("김대연")
                    .font(.moneySnap(size: 20, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                Text("오늘 Snap 3개 · 그룹 3개")
                    .font(.moneySnap(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 138.0 / 255, green: 141.0 / 255, blue: 153.0 / 255))
                Text("기본 비공개")
                    .font(.moneySnap(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 46.0 / 255, green: 48.0 / 255, blue: 56.0 / 255))
                    .frame(width: 90, height: 24)
                    .background(Color(red: 240.0 / 255, green: 241.0 / 255, blue: 244.0 / 255), in: Capsule())
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 19)
        .frame(width: 345, height: 112)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(red: 239.0 / 255, green: 239.0 / 255, blue: 242.0 / 255))
        }
        .offset(x: 24, y: 82)
    }

    private var monthlySummary: some View {
        Group {
            Text("이번 달")
                .font(.moneySnap(size: 17, weight: .bold))
                .foregroundStyle(MoneySnapVisualSystem.ink)
                .offset(x: 28, y: 230)

            HStack(spacing: 15) {
                statCard(label: "기록한 Snap", value: "42개")
                statCard(label: "공유 그룹", value: "3개")
            }
            .offset(x: 24, y: 264)
        }
    }

    private var settingsRows: some View {
        VStack(spacing: 16) {
            settingsRow(title: "내 그룹 관리", subtitle: "그룹과 초대 설정")
            Button {
                authentication.clearIssue()
                presentsAccountSettings = true
            } label: {
                settingsRow(title: "앱 설정", subtitle: "접근성, 계정")
            }
            .buttonStyle(.plain)
            settingsRow(title: "도움말", subtitle: "Money Snap 사용 가이드")
        }
        .offset(x: 24, y: 396)
    }

    private func statCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.moneySnap(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 138.0 / 255, green: 141.0 / 255, blue: 153.0 / 255))
            Text(value)
                .font(.moneySnap(size: 28, weight: .black))
                .foregroundStyle(MoneySnapVisualSystem.ink)
        }
        .padding(.horizontal, 17)
        .frame(width: 165, height: 92, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 239.0 / 255, green: 239.0 / 255, blue: 242.0 / 255))
        }
    }

    private func settingsRow(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.moneySnap(size: 15, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                Text(subtitle)
                    .font(.moneySnap(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 138.0 / 255, green: 141.0 / 255, blue: 153.0 / 255))
            }
            Spacer()
            Text("열기")
                .font(.moneySnap(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 138.0 / 255, green: 141.0 / 255, blue: 153.0 / 255))
        }
        .padding(.horizontal, 17)
        .frame(width: 345, height: 64)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 239.0 / 255, green: 239.0 / 255, blue: 242.0 / 255))
        }
    }
}

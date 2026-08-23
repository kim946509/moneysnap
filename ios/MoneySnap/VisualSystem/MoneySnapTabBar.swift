import SwiftUI

struct MoneySnapTabBar: View {
    @Binding var selectedTab: AppTab
    let onSelect: (AppTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 24, weight: .medium))
                            .frame(height: 27)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(selectedTab == tab ? Color.blue : Color.black)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background {
                        if selectedTab == tab {
                            Circle()
                                .fill(Color.blue.opacity(0.09))
                                .frame(width: 51, height: 51)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 58)
                .contentShape(Rectangle())
                .accessibilityIdentifier("tab.\(tab.rawValue)")
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 5)
        .frame(height: 58)
        .background(.white.opacity(0.94), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.75), lineWidth: 1))
        .shadow(color: .black.opacity(0.11), radius: 14, y: 5)
    }
}

struct MoneySnapMenuButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(MoneySnapVisualSystem.navy, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 12, y: 9)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("메뉴")
        .accessibilityIdentifier("app.menu")
    }
}

struct MoneySnapSidebar: View {
    let selectedTab: AppTab
    let onSelectTab: (AppTab) -> Void
    let onHelp: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityLabel("메뉴 닫기")
                .accessibilityIdentifier("menu.dismiss")

            VStack(alignment: .leading, spacing: 8) {
                Text("메뉴")
                    .font(.moneySnap(size: 22, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                    .padding(.top, 28)
                    .padding(.bottom, 12)

                ForEach([AppTab.home, .group, .archive, .profile], id: \.self) { tab in
                    Button {
                        onSelectTab(tab)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: tab.systemImage)
                                .frame(width: 24)
                            Text(tab.title)
                                .font(.moneySnap(size: 17, weight: .bold))
                            Spacer()
                        }
                        .foregroundStyle(selectedTab == tab ? MoneySnapVisualSystem.ink : MoneySnapVisualSystem.secondaryText)
                        .frame(minHeight: 48)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("menu.\(tab.rawValue)")
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }

                Button(action: onHelp) {
                    HStack(spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .frame(width: 24)
                        Text("도움말")
                            .font(.moneySnap(size: 17, weight: .bold))
                        Spacer()
                    }
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                    .frame(minHeight: 48)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("menu.help")

                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(width: 280)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("screen.menu")
        }
    }
}

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

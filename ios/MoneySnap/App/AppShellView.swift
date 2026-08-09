import SwiftUI

struct AppShellView: View {
    @Binding var selectedTab: AppTab
    @State private var tabRouter = TabRouter()
    private let snapJournalClient: any SnapJournalClient

    init(
        selectedTab: Binding<AppTab>,
        snapJournalClient: any SnapJournalClient = InMemorySnapJournalClient.fixture
    ) {
        _selectedTab = selectedTab
        self.snapJournalClient = snapJournalClient
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    NavigationStack(path: tabRouter.binding(for: tab)) {
                        rootView(for: tab)
                            .navigationDestination(for: AppRoute.self) { route in
                                RoutePlaceholderView(route: route)
                            }
                    }
                    .environment(tabRouter.router(for: tab))
                    .tabItem { tab.label }
                    .tag(tab)
                }
            }
            .toolbar(.hidden, for: .tabBar)

            MoneySnapTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 18)
                .padding(.bottom, 21)
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    @ViewBuilder
    private func rootView(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            TodaySnapView(
                client: snapJournalClient,
                onRecord: { selectedTab = .add },
                onMenu: { selectedTab = .profile }
            )
        default:
            PlaceholderView(
                title: tab.presentation.title,
                systemImage: tab.presentation.systemImage
            )
        }
    }
}

private struct MoneySnapTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: tab.presentation.systemImage)
                            .font(.system(size: 24, weight: .medium))
                            .frame(height: 27)
                        Text(tab.presentation.title)
                            .font(.system(size: 10, weight: .bold))
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
            }
        }
        .padding(.horizontal, 5)
        .frame(height: 58)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.75), lineWidth: 1))
        .shadow(color: .black.opacity(0.11), radius: 14, y: 5)
    }
}

private extension AppTab {
    var presentation: AppTabPresentation {
        switch self {
        case .home: AppTabPresentation(title: "홈", systemImage: "house")
        case .group: AppTabPresentation(title: "그룹", systemImage: "person")
        case .add: AppTabPresentation(title: "추가", systemImage: "plus")
        case .archive: AppTabPresentation(title: "보관함", systemImage: "folder")
        case .profile: AppTabPresentation(title: "마이", systemImage: "person.crop.circle")
        }
    }

    @ViewBuilder
    var label: some View {
        Label(presentation.title, systemImage: presentation.systemImage)
    }
}

private struct AppTabPresentation {
    let title: String
    let systemImage: String
}

private struct RoutePlaceholderView: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .snapDetail:
            PlaceholderView(title: "Snap 상세", systemImage: "photo")
        }
    }
}

#Preview {
    AppShellView(selectedTab: .constant(.home))
}

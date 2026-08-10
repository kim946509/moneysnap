import Foundation
import SwiftUI

struct AppShellView: View {
    @Binding var selectedTab: AppTab
    @State private var tabRouter = TabRouter()
    private let authentication: AuthenticationModel
    private let snapJournalClient: any SnapJournalClient

    init(
        selectedTab: Binding<AppTab>,
        authentication: AuthenticationModel,
        snapJournalClient: any SnapJournalClient = InMemorySnapJournalClient.fixture
    ) {
        _selectedTab = selectedTab
        self.authentication = authentication
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
                client: snapJournalClient
            )
        case .profile:
            MySettingsView(authentication: authentication)
        default:
            PlaceholderView(
                title: tab.title,
                systemImage: tab.systemImage
            )
        }
    }
}

private extension AppTab {
    @ViewBuilder
    var label: some View {
        Label(title, systemImage: systemImage)
    }
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
    AppShellView(
        selectedTab: .constant(.home),
        authentication: AuthenticationModel(
            api: URLSessionAuthenticationAPI(baseURL: URL(string: "https://example.invalid")!),
            store: KeychainSessionStore(),
            initialPhase: .signedOut
        )
    )
}

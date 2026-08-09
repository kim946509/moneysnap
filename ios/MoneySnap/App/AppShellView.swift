import SwiftUI

struct AppShellView: View {
    @Binding var selectedTab: AppTab
    @State private var tabRouter = TabRouter()

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: tabRouter.binding(for: tab)) {
                    tab.makeRootView()
                        .navigationDestination(for: AppRoute.self) { route in
                            RoutePlaceholderView(route: route)
                        }
                }
                .environment(tabRouter.router(for: tab))
                .tabItem { tab.label }
                .tag(tab)
            }
        }
    }
}

private extension AppTab {
    var presentation: AppTabPresentation {
        switch self {
        case .home: AppTabPresentation(title: "홈", systemImage: "house")
        case .group: AppTabPresentation(title: "그룹", systemImage: "person.2")
        case .add: AppTabPresentation(title: "추가", systemImage: "plus.circle.fill")
        case .archive: AppTabPresentation(title: "보관함", systemImage: "archivebox")
        case .profile: AppTabPresentation(title: "마이", systemImage: "person.crop.circle")
        }
    }

    @ViewBuilder
    func makeRootView() -> some View {
        PlaceholderView(
            title: presentation.title,
            systemImage: presentation.systemImage
        )
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

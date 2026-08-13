import Foundation
import SwiftUI

struct AppShellView: View {
    @Binding var selectedTab: AppTab
    @State private var tabRouter = TabRouter()
    @State private var presentedSheet: AppSheet?
    @State private var todayViewModel: TodaySnapViewModel
    private let authentication: AuthenticationModel
    private let snapJournalClient: any SnapJournalClient
    private let initialCaptureModel: SnapCaptureModel?

    init(
        selectedTab: Binding<AppTab>,
        authentication: AuthenticationModel,
        snapJournalClient: any SnapJournalClient,
        initialCaptureModel: SnapCaptureModel? = nil
    ) {
        _selectedTab = selectedTab
        _todayViewModel = State(initialValue: TodaySnapViewModel(client: snapJournalClient))
        _presentedSheet = State(initialValue: initialCaptureModel == nil ? nil : .record)
        self.authentication = authentication
        self.snapJournalClient = snapJournalClient
        self.initialCaptureModel = initialCaptureModel
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

            MoneySnapTabBar(selectedTab: $selectedTab) { tab in
                if tab == .add {
                    presentedSheet = .record
                } else {
                    selectedTab = tab
                }
            }
                .padding(.horizontal, 18)
                .padding(.bottom, 21)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .record:
                SnapCaptureView(
                    model: initialCaptureModel ?? makeCaptureModel(),
                    onSaved: apply
                )
            }
        }
        .onAppear {
            if initialCaptureModel != nil {
                presentedSheet = .record
            }
        }
    }

    @ViewBuilder
    private func rootView(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            TodaySnapView(
                viewModel: todayViewModel,
                onRecord: { presentedSheet = .record }
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

    private func apply(_ receipt: SnapRecordReceipt) {
        _ = todayViewModel.apply(receipt)
        selectedTab = .home
    }

    private func makeCaptureModel() -> SnapCaptureModel {
        SnapCaptureModel { command in
            try await snapJournalClient.record(command)
        }
    }
}

private enum AppSheet: String, Identifiable {
    case record
    var id: String { rawValue }
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

#if DEBUG
#Preview {
    AppShellView(
        selectedTab: .constant(.home),
        authentication: VisualTestSupport.authenticatedModel(),
        snapJournalClient: VisualTestSupport.snapJournalClient
    )
}
#endif

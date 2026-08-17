import Foundation
import SwiftUI

struct AppShellView: View {
    @Binding var selectedTab: AppTab
    @State private var tabRouter = TabRouter()
    @State private var presentedSheet: AppSheet?
    @State private var todayViewModel: TodaySnapViewModel
    @State private var shareGroups: [MoneySnapGroup] = []
    private let authentication: AuthenticationModel
    private let snapJournalClient: any SnapJournalClient
    private let groupClient: any GroupClient
    private let mediaClient: (any MediaClient)?
    private let initialCaptureModel: SnapCaptureModel?

    init(
        selectedTab: Binding<AppTab>,
        authentication: AuthenticationModel,
        snapJournalClient: any SnapJournalClient,
        groupClient: any GroupClient = UnavailableGroupClient(),
        mediaClient: (any MediaClient)? = nil,
        initialCaptureModel: SnapCaptureModel? = nil
    ) {
        _selectedTab = selectedTab
        _todayViewModel = State(initialValue: TodaySnapViewModel(client: snapJournalClient))
        _presentedSheet = State(initialValue: initialCaptureModel == nil ? nil : .record)
        self.authentication = authentication
        self.snapJournalClient = snapJournalClient
        self.groupClient = groupClient
        self.mediaClient = mediaClient
        self.initialCaptureModel = initialCaptureModel
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    NavigationStack(path: tabRouter.binding(for: tab)) {
                        rootView(for: tab)
                            .navigationDestination(for: AppRoute.self) { route in
                                switch route {
                                case let .snapDetail(id):
                                    SnapDetailView(
                                        model: SnapDetailModel(snapID: id, client: snapJournalClient),
                                        onChanged: { detail in
                                            todayViewModel.replace(detail)
                                        },
                                        onDeleted: {
                                            todayViewModel.remove(id)
                                            tabRouter.router(for: tab).path.removeAll()
                                            Task { await todayViewModel.refresh() }
                                        },
                                        groups: shareGroups,
                                        onShare: { groupID in
                                            Task {
                                                try? await groupClient.share(
                                                    snapID: id,
                                                    groupID: groupID,
                                                    mutationID: UUID().uuidString.lowercased()
                                                )
                                            }
                                        }
                                    )
                                }
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
            case let .share(receipt):
                ShareAfterSaveView(
                    groups: shareGroups,
                    onShare: { groupID in
                        Task {
                            try? await groupClient.share(
                                snapID: receipt.id,
                                groupID: groupID,
                                mutationID: UUID().uuidString.lowercased()
                            )
                            presentedSheet = nil
                        }
                    },
                    onSkip: { presentedSheet = nil }
                )
            }
        }
        .onAppear {
            if initialCaptureModel != nil {
                presentedSheet = .record
            }
            Task {
                shareGroups = (try? await groupClient.list().groups) ?? []
            }
        }
    }

    @ViewBuilder
    private func rootView(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            TodaySnapView(
                viewModel: todayViewModel,
                onRecord: { presentedSheet = .record },
                onOpen: { id in
                    tabRouter.router(for: .home).navigate(to: .snapDetail(id: id))
                }
            )
        case .group:
            GroupListView(client: groupClient)
        case .archive:
            ArchiveView(client: snapJournalClient) { id in
                tabRouter.router(for: .archive).navigate(to: .snapDetail(id: id))
            }
        case .profile:
            MySettingsView(
                authentication: authentication,
                summaryClient: URLSessionAccountSummaryClient(
                    baseURL: URL(string: "https://moneysnap-server.ansandy.co.kr")!,
                    accessToken: { try await authentication.accessTokenForRequest() }
                )
            )
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
        Task { await todayViewModel.refresh() }
        if !shareGroups.isEmpty {
            presentedSheet = .share(receipt)
        }
    }

    private func makeCaptureModel() -> SnapCaptureModel {
        #if DEBUG
        if ProcessInfo.processInfo.environment["MONEYSNAP_FEATURE_SCENARIO"] != nil {
            return SnapCaptureModel(
                record: { try await snapJournalClient.record($0) },
                now: { Date(timeIntervalSince1970: 1_786_582_800) },
                timeZone: { TimeZone(identifier: "Asia/Seoul")! }
            )
        }
        #endif
        let mediaClient = mediaClient
        return SnapCaptureModel(
            record: { try await snapJournalClient.record($0) },
            allowsPhotos: true,
            publishPhoto: mediaClient.map { client in
                { jpeg in try await client.publish(jpeg) }
            }
        )
    }
}

private enum AppSheet: Identifiable {
    case record
    case share(SnapRecordReceipt)

    var id: String {
        switch self {
        case .record:
            "record"
        case let .share(receipt):
            "share-\(receipt.id.uuidString)"
        }
    }
}

private struct ShareAfterSaveView: View {
    let groups: [MoneySnapGroup]
    let onShare: (UUID) -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            List(groups) { group in
                Button(group.name) { onShare(group.id) }
                    .frame(minWidth: 44, minHeight: 44)
            }
            .navigationTitle("그룹에 공유")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("건너뛰기", action: onSkip)
                        .accessibilityIdentifier("share.skip")
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private extension AppTab {
    @ViewBuilder
    var label: some View {
        Label(title, systemImage: systemImage)
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

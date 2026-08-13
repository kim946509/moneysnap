import Foundation
import SwiftUI

@main
@MainActor
struct MoneySnapApp: App {
    @State private var selectedTab: AppTab
    @State private var authentication: AuthenticationModel
    private let snapJournalClient: any SnapJournalClient
    #if DEBUG
    private let invalidVisualScenario: String?
    #endif

    init() {
        #if DEBUG
        switch VisualTestSupport.resolve(environment: ProcessInfo.processInfo.environment) {
        case .live:
            _selectedTab = State(initialValue: .initial)
            _authentication = State(initialValue: Self.liveAuthenticationModel())
            snapJournalClient = UnavailableSnapJournalClient()
            invalidVisualScenario = nil
        case let .scenario(scenario):
            _selectedTab = State(initialValue: scenario.initialTab)
            _authentication = State(initialValue: VisualTestSupport.authenticatedModel())
            snapJournalClient = VisualTestSupport.snapJournalClient
            invalidVisualScenario = nil
        case let .invalid(scenario):
            _selectedTab = State(initialValue: .initial)
            _authentication = State(initialValue: VisualTestSupport.failClosedModel())
            snapJournalClient = UnavailableSnapJournalClient()
            invalidVisualScenario = scenario
        }
        #else
        _selectedTab = State(initialValue: .initial)
        _authentication = State(initialValue: Self.liveAuthenticationModel())
        snapJournalClient = UnavailableSnapJournalClient()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let invalidVisualScenario {
                VisualLaunchFailureView(scenario: invalidVisualScenario)
            } else {
                appRoot
            }
            #else
            appRoot
            #endif
        }
    }

    private var appRoot: some View {
        AuthenticationGateView(
            authentication: authentication,
            selectedTab: $selectedTab,
            snapJournalClient: snapJournalClient
        )
    }

    private static func liveAuthenticationModel() -> AuthenticationModel {
        AuthenticationModel(
            api: URLSessionAuthenticationAPI(
                baseURL: URL(string: "https://moneysnap-server.ansandy.co.kr")!
            ),
            store: KeychainSessionStore()
        )
    }
}

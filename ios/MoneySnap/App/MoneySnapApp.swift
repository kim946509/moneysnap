import Foundation
import SwiftUI

@main
@MainActor
struct MoneySnapApp: App {
    @State private var selectedTab: AppTab
    @State private var authentication: AuthenticationModel
    private let snapJournalClient: any SnapJournalClient
    private let groupClient: any GroupClient
    private let mediaClient: (any MediaClient)?
    private let initialCaptureModel: SnapCaptureModel?
    #if DEBUG
    private let invalidVisualScenario: String?
    #endif

    init() {
        #if DEBUG
        switch VisualTestSupport.resolveFeature(environment: ProcessInfo.processInfo.environment) {
        case .record:
            _selectedTab = State(initialValue: .home)
            _authentication = State(initialValue: VisualTestSupport.authenticatedModel())
            snapJournalClient = VisualTestSupport.recordFeatureClient
            groupClient = UnavailableGroupClient()
            mediaClient = nil
            initialCaptureModel = nil
            invalidVisualScenario = nil
            return
        case .recordRetry:
            _selectedTab = State(initialValue: .home)
            _authentication = State(initialValue: VisualTestSupport.authenticatedModel())
            snapJournalClient = VisualTestSupport.recordRetryFeatureClient
            groupClient = UnavailableGroupClient()
            mediaClient = nil
            initialCaptureModel = nil
            invalidVisualScenario = nil
            return
        case .todayMany:
            _selectedTab = State(initialValue: .home)
            _authentication = State(initialValue: VisualTestSupport.authenticatedModel())
            snapJournalClient = VisualTestSupport.todayManyFeatureClient
            groupClient = UnavailableGroupClient()
            mediaClient = nil
            initialCaptureModel = nil
            invalidVisualScenario = nil
            return
        case let .invalid(scenario):
            _selectedTab = State(initialValue: .home)
            _authentication = State(initialValue: VisualTestSupport.failClosedModel())
            snapJournalClient = UnavailableSnapJournalClient()
            groupClient = UnavailableGroupClient()
            mediaClient = nil
            initialCaptureModel = nil
            invalidVisualScenario = scenario
            return
        case .absent:
            break
        }
        switch VisualTestSupport.resolve(environment: ProcessInfo.processInfo.environment) {
        case .live:
            let authentication = Self.liveAuthenticationModel()
            _selectedTab = State(initialValue: .initial)
            _authentication = State(initialValue: authentication)
            snapJournalClient = Self.liveSnapJournalClient(authentication: authentication)
            groupClient = Self.liveGroupClient(authentication: authentication)
            mediaClient = Self.liveMediaClient(authentication: authentication)
            initialCaptureModel = nil
            invalidVisualScenario = nil
        case let .scenario(scenario):
            let client = VisualTestSupport.snapJournalClient
            _selectedTab = State(initialValue: scenario.initialTab)
            _authentication = State(initialValue: VisualTestSupport.authenticatedModel())
            snapJournalClient = client
            groupClient = UnavailableGroupClient()
            mediaClient = nil
            initialCaptureModel = VisualTestSupport.initialCaptureModel(
                for: scenario,
                client: client
            )
            invalidVisualScenario = nil
        case let .invalid(scenario):
            _selectedTab = State(initialValue: .initial)
            _authentication = State(initialValue: VisualTestSupport.failClosedModel())
            snapJournalClient = UnavailableSnapJournalClient()
            groupClient = UnavailableGroupClient()
            mediaClient = nil
            initialCaptureModel = nil
            invalidVisualScenario = scenario
        }
        #else
        let authentication = Self.liveAuthenticationModel()
        _selectedTab = State(initialValue: .initial)
        _authentication = State(initialValue: authentication)
        snapJournalClient = Self.liveSnapJournalClient(authentication: authentication)
        groupClient = Self.liveGroupClient(authentication: authentication)
        mediaClient = Self.liveMediaClient(authentication: authentication)
        initialCaptureModel = nil
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
            snapJournalClient: snapJournalClient,
            groupClient: groupClient,
            mediaClient: mediaClient,
            initialCaptureModel: initialCaptureModel
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

    private static func liveGroupClient(
        authentication: AuthenticationModel
    ) -> any GroupClient {
        URLSessionGroupClient(
            baseURL: URL(string: "https://moneysnap-server.ansandy.co.kr")!,
            accessToken: { try await authentication.accessTokenForRequest() }
        )
    }

    private static func liveMediaClient(
        authentication: AuthenticationModel
    ) -> any MediaClient {
        URLSessionMediaClient(
            baseURL: URL(string: "https://moneysnap-server.ansandy.co.kr")!,
            accessToken: { try await authentication.accessTokenForRequest() }
        )
    }

    private static func liveSnapJournalClient(
        authentication: AuthenticationModel
    ) -> any SnapJournalClient {
        URLSessionSnapJournalClient(
            baseURL: URL(string: "https://moneysnap-server.ansandy.co.kr")!,
            accessToken: { try await authentication.accessTokenForRequest() },
            sessionRejected: { token in
                await authentication.handleSessionRejection(for: token)
            }
        )
    }
}

import Foundation
import SwiftUI

@main
@MainActor
struct MoneySnapApp: App {
    @State private var selectedTab: AppTab
    @State private var authentication: AuthenticationModel

    init() {
        #if DEBUG
        let requestedScenario = ProcessInfo.processInfo.environment["MONEYSNAP_VISUAL_SCENARIO"]
        let scenario = requestedScenario.flatMap { ["home", "my"].contains($0) ? $0 : nil }
        #else
        let scenario: String? = nil
        #endif
        _selectedTab = State(initialValue: scenario == "my" ? .profile : .home)
        _authentication = State(initialValue: AuthenticationModel(
            api: URLSessionAuthenticationAPI(
                baseURL: URL(string: "https://moneysnap-server.ansandy.co.kr")!
            ),
            store: KeychainSessionStore(),
            initialPhase: scenario == nil ? .restoring : .authenticated(.visualFixture)
        ))
    }

    var body: some Scene {
        WindowGroup {
            AuthenticationGateView(
                authentication: authentication,
                selectedTab: $selectedTab
            )
        }
    }
}

private extension AuthenticationSession {
    static let visualFixture = AuthenticationSession(
        accessToken: "visual-access-token",
        accessExpiresAt: Date.distantFuture,
        refreshToken: "visual-refresh-token",
        refreshExpiresAt: Date.distantFuture
    )
}

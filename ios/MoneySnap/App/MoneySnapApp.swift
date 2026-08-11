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
        #if DEBUG
        let model = if scenario == nil {
            AuthenticationModel(
                api: URLSessionAuthenticationAPI(
                    baseURL: URL(string: "https://moneysnap-server.ansandy.co.kr")!
                ),
                store: KeychainSessionStore()
            )
        } else {
            AuthenticationModel(
                api: VisualAuthenticationAPI(),
                store: VisualSessionStore(session: .visualFixture),
                initialPhase: .authenticated(.visualFixture)
            )
        }
        #else
        let model = AuthenticationModel(
            api: URLSessionAuthenticationAPI(
                baseURL: URL(string: "https://moneysnap-server.ansandy.co.kr")!
            ),
            store: KeychainSessionStore()
        )
        #endif
        _authentication = State(initialValue: model)
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

#if DEBUG
private actor VisualAuthenticationAPI: AuthenticationAPI {
    func signIn(with credential: AppleSignInCredential) -> AuthenticationSession { .visualFixture }
    func refresh(_ refreshToken: String) -> AuthenticationSession { .visualFixture }
    func logout(accessToken: String) {}
    func deleteAccount(accessToken: String, credential: AppleSignInCredential) {}
}

private actor VisualSessionStore: SessionStore {
    private var session: AuthenticationSession?

    init(session: AuthenticationSession?) {
        self.session = session
    }

    func load() -> AuthenticationSession? { session }
    func save(_ session: AuthenticationSession) { self.session = session }
    func clear() { session = nil }
}
#endif

private extension AuthenticationSession {
    static let visualFixture = AuthenticationSession(
        accessToken: "visual-access-token",
        accessExpiresAt: Date.distantFuture,
        refreshToken: "visual-refresh-token",
        refreshExpiresAt: Date.distantFuture
    )
}

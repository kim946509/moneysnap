#if DEBUG
import Foundation
import SwiftUI

enum VisualScenario: String, CaseIterable, Sendable {
    case home
    case my

    var initialTab: AppTab {
        switch self {
        case .home: .home
        case .my: .profile
        }
    }
}

enum VisualLaunchRequest: Equatable, Sendable {
    case live
    case scenario(VisualScenario)
    case invalid(String)
}

@MainActor
enum VisualTestSupport {
    static func resolve(environment: [String: String]) -> VisualLaunchRequest {
        guard let rawValue = environment["MONEYSNAP_VISUAL_SCENARIO"] else {
            return .live
        }
        guard let scenario = VisualScenario(rawValue: rawValue) else {
            return .invalid(rawValue)
        }
        return .scenario(scenario)
    }

    static func authenticatedModel() -> AuthenticationModel {
        AuthenticationModel(
            api: VisualAuthenticationAPI(session: session),
            store: VisualSessionStore(session: session),
            initialPhase: .authenticated(session)
        )
    }

    static func failClosedModel() -> AuthenticationModel {
        AuthenticationModel(
            api: VisualAuthenticationAPI(session: session),
            store: VisualSessionStore(session: nil),
            initialPhase: .restoreFailed
        )
    }

    static var snapJournalClient: any SnapJournalClient {
        InMemorySnapJournalClient(summary: homeSummary)
    }

    private static let session = AuthenticationSession(
        accessToken: "visual-access-token",
        accessExpiresAt: .distantFuture,
        refreshToken: "visual-refresh-token",
        refreshExpiresAt: .distantFuture
    )

    static let homeSummary: TodaySnapSummary = {
        guard
            let foodID = UUID(uuidString: "FEED0000-0000-4000-8000-000000000001"),
            let cafeID = UUID(uuidString: "CAFE0000-0000-4000-8000-000000000002"),
            let transportationID = UUID(uuidString: "B0000000-0000-4000-8000-000000000003"),
            let livingID = UUID(uuidString: "B0000000-0000-4000-8000-000000000004")
        else {
            preconditionFailure("Visual fixture UUIDs must remain valid.")
        }

        do {
            return try TodaySnapSummary(
                day: SnapDay(year: 2026, month: 6, day: 3, weekday: .wednesday),
                entries: [
                    TodaySnapEntry(id: foodID, category: .food, amount: try KrwAmount(18_900), artwork: .food),
                    TodaySnapEntry(id: cafeID, category: .cafe, amount: try KrwAmount(5_200), artwork: .cafe),
                    TodaySnapEntry(id: transportationID, category: .transportation, amount: try KrwAmount(2_800), artwork: nil),
                    TodaySnapEntry(id: livingID, category: .living, amount: try KrwAmount(16_300), artwork: nil)
                ],
                featuredEntryIDs: [foodID, cafeID, transportationID],
                recentEntryIDs: [foodID, cafeID]
            )
        } catch {
            preconditionFailure("Visual fixture must satisfy the Snap model: \(error)")
        }
    }()
}

private struct InMemorySnapJournalClient: SnapJournalClient {
    let summary: TodaySnapSummary

    func fetchToday() async throws -> TodaySnapSummary {
        summary
    }
}

struct VisualLaunchFailureView: View {
    let scenario: String

    var body: some View {
        ContentUnavailableView(
            "지원하지 않는 시각 검증 시나리오",
            systemImage: "xmark.octagon",
            description: Text(scenario.isEmpty ? "<empty>" : scenario)
        )
        .accessibilityIdentifier("screen.visual-launch-failure")
    }
}

private actor VisualAuthenticationAPI: AuthenticationAPI {
    private let session: AuthenticationSession

    init(session: AuthenticationSession) {
        self.session = session
    }

    func signIn(with credential: AppleSignInCredential) -> AuthenticationSession {
        session
    }

    func refresh(_ refreshToken: String) -> AuthenticationSession {
        session
    }

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

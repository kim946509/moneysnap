#if DEBUG
import Foundation
import SwiftUI

enum VisualScenario: String, CaseIterable, Sendable {
    case home
    case my
    case recordCategory = "record-category"
    case recordAmount = "record-amount"

    var initialTab: AppTab {
        switch self {
        case .home, .recordCategory, .recordAmount: .home
        case .my: .profile
        }
    }
}

enum VisualLaunchRequest: Equatable, Sendable {
    case live
    case scenario(VisualScenario)
    case invalid(String)
}

enum FeatureLaunchRequest: Equatable, Sendable {
    case absent
    case record
    case recordRetry
    case invalid(String)
}

@MainActor
enum VisualTestSupport {
    static func resolveFeature(environment: [String: String]) -> FeatureLaunchRequest {
        guard let rawValue = environment["MONEYSNAP_FEATURE_SCENARIO"] else { return .absent }
        switch rawValue {
        case "record": .record
        case "record-retry": .recordRetry
        default: .invalid(rawValue)
        }
    }

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

    static var recordFeatureClient: any SnapJournalClient {
        RecordFeatureSnapJournalClient(summary: recordFeatureSummary)
    }

    static var recordRetryFeatureClient: any SnapJournalClient {
        RecordRetrySnapJournalClient(summary: recordFeatureSummary)
    }

    static func initialCaptureModel(
        for scenario: VisualScenario,
        client: any SnapJournalClient
    ) -> SnapCaptureModel? {
        guard scenario == .recordCategory || scenario == .recordAmount else { return nil }
        let model = SnapCaptureModel(
            record: { try await client.record($0) },
            now: { Date(timeIntervalSince1970: 1_780_415_400) },
            timeZone: { TimeZone(identifier: "Asia/Seoul")! },
            mutationID: { UUID(uuidString: "11111111-1111-4111-8111-111111111111")! }
        )
        if scenario == .recordCategory {
            model.select(.food)
            model.goBack()
        } else if scenario == .recordAmount {
            model.select(.food)
            [1, 8, 9, 0, 0].forEach(model.appendDigit)
        }
        return model
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

    private static let recordFeatureSummary: TodaySnapSummary = {
        do {
            return try TodaySnapSummary(
                day: SnapDay(year: 2026, month: 8, day: 13, weekday: .thursday),
                entries: homeSummary.entries,
                featuredEntryIDs: homeSummary.featuredEntryIDs,
                recentEntryIDs: homeSummary.recentEntryIDs
            )
        } catch {
            preconditionFailure("Record feature fixture must satisfy the Snap model: \(error)")
        }
    }()
}

private struct InMemorySnapJournalClient: SnapJournalClient {
    let summary: TodaySnapSummary

    func fetchToday() async throws -> TodaySnapSummary {
        summary
    }

    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt {
        throw SnapRecordError.transportFailure
    }
}

private actor RecordFeatureSnapJournalClient: SnapJournalClient {
    let summary: TodaySnapSummary

    func fetchToday() async throws -> TodaySnapSummary { summary }

    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt {
        SnapRecordReceipt(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            category: command.category,
            amountWon: command.amountWon,
            localDay: command.localDay,
            createdAt: Date(timeIntervalSince1970: 1_786_582_800)
        )
    }
}

private actor RecordRetrySnapJournalClient: SnapJournalClient {
    let summary: TodaySnapSummary
    private var attempts = 0

    func fetchToday() async throws -> TodaySnapSummary { summary }

    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt {
        attempts += 1
        guard attempts > 1 else { throw SnapRecordError.transportFailure }
        return SnapRecordReceipt(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            category: command.category,
            amountWon: command.amountWon,
            localDay: command.localDay,
            createdAt: Date(timeIntervalSince1970: 1_786_582_800)
        )
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

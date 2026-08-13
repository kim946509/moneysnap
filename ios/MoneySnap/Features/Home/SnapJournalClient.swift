import Foundation

protocol SnapJournalClient: Sendable {
    func fetchToday() async throws -> TodaySnapSummary
}

enum SnapJournalClientError: Error {
    case unavailable
}

struct UnavailableSnapJournalClient: SnapJournalClient {
    func fetchToday() async throws -> TodaySnapSummary {
        throw SnapJournalClientError.unavailable
    }
}

import Observation

@MainActor
@Observable
final class TodaySnapViewModel {
    enum State: Equatable {
        case loading
        case content(TodaySnapSummary)
        case failure
    }

    private(set) var state: State = .loading
    private let client: any SnapJournalClient

    init(client: any SnapJournalClient) {
        self.client = client
    }

    func load() async {
        do {
            state = .content(try await client.fetchToday())
        } catch {
            state = .failure
        }
    }
}

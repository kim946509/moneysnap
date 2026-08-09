import Testing
@testable import MoneySnap

@MainActor
struct TodaySnapViewModelTests {
    @Test
    func loadsTheFigmaHomeFixtureThroughTheJournalClient() async {
        let viewModel = TodaySnapViewModel(client: InMemorySnapJournalClient.fixture)

        #expect(viewModel.state == .loading)
        await viewModel.load()

        guard case let .content(summary) = viewModel.state else {
            Issue.record("Expected Today Snap content")
            return
        }
        #expect(summary.totalAmount == 43_200)
        #expect(summary.featuredEntries.map(\.category) == [.food, .cafe, .transportation])
        #expect(summary.recentEntries.map(\.amount) == [18_900, 5_200])
    }

    @Test
    func exposesFailureWhenTheJournalClientCannotLoad() async {
        let viewModel = TodaySnapViewModel(client: FailingSnapJournalClient())

        await viewModel.load()

        #expect(viewModel.state == .failure)
    }
}

private struct FailingSnapJournalClient: SnapJournalClient {
    func fetchToday() async throws -> TodaySnapSummary {
        throw FixtureError.unavailable
    }
}

private enum FixtureError: Error {
    case unavailable
}

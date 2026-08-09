import Foundation
import Testing
@testable import MoneySnap

@MainActor
struct TodaySnapViewModelTests {
    @Test
    func moneyRejectsZeroAndNegativeValues() {
        assertInvalidAmount(0)
        assertInvalidAmount(-1)
    }

    @Test
    func summaryRejectsAnOverflowingTotal() throws {
        let first = TodaySnapEntry(
            id: UUID(),
            category: .food,
            amount: try KrwAmount(Int64.max),
            artwork: nil
        )
        let second = TodaySnapEntry(
            id: UUID(),
            category: .cafe,
            amount: try KrwAmount(1),
            artwork: nil
        )

        do {
            _ = try TodaySnapSummary(
                day: .figmaReference,
                entries: [first, second],
                featuredEntryIDs: [],
                recentEntryIDs: []
            )
            Issue.record("Expected an overflowing total to fail")
        } catch {
            #expect(error as? SnapModelError == .totalOverflow)
        }
    }

    @Test
    func canvasSizeIsDerivedFromTheAmountRatio() {
        let summary = TodaySnapSummary.figmaHome
        let largest = TodayCanvasLayout.imageSize(
            for: summary.featuredEntries[0],
            maximumAmount: summary.featuredEntries[0].amount
        )
        let smaller = TodayCanvasLayout.imageSize(
            for: summary.featuredEntries[1],
            maximumAmount: summary.featuredEntries[0].amount
        )

        #expect(largest.width == 150)
        #expect(smaller.width < largest.width)
    }

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
        #expect(summary.recentEntries.map(\.amount.value) == [18_900, 5_200])
    }

    @Test
    func exposesFailureWhenTheJournalClientCannotLoad() async {
        let viewModel = TodaySnapViewModel(client: FailingSnapJournalClient())

        await viewModel.load()

        #expect(viewModel.state == .failure)
    }

    private func assertInvalidAmount(_ value: Int64) {
        do {
            _ = try KrwAmount(value)
            Issue.record("Expected \(value) KRW to be rejected")
        } catch {
            #expect(error as? SnapModelError == .nonPositiveAmount)
        }
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

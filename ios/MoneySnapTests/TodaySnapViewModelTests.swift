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
    func moneyAcceptsTheUpperBoundAndRejectsOneWonAboveIt() throws {
        #expect(try KrwAmount(999_999_999).value == 999_999_999)
        assertInvalidAmount(1_000_000_000, expected: .amountAboveLimit)
    }

    @Test
    func summarySafelyTotalsDomainMaximumAmounts() throws {
        let first = TodaySnapEntry(
            id: UUID(),
            category: .food,
            amount: try KrwAmount(999_999_999),
            artwork: nil
        )
        let second = TodaySnapEntry(
            id: UUID(),
            category: .cafe,
            amount: try KrwAmount(1),
            artwork: nil
        )

        let summary = try TodaySnapSummary(
            day: SnapDay(year: 2026, month: 6, day: 3, weekday: .wednesday),
            entries: [first, second],
            featuredEntryIDs: [],
            recentEntryIDs: []
        )

        #expect(summary.totalAmount == 1_000_000_000)
    }

    @Test
    func canvasSizeIsDerivedFromTheAmountRatio() {
        let summary = VisualTestSupport.homeSummary
        let largest = TodayCanvasLayout.imageSize(
            for: summary.featuredEntries[0],
            maximumAmount: summary.featuredEntries[0].amount
        )
        let smaller = TodayCanvasLayout.imageSize(
            for: summary.featuredEntries[1],
            maximumAmount: summary.featuredEntries[0].amount
        )

        #expect(largest.width == 144)
        #expect(smaller.width < largest.width)
    }

    @Test
    func loadsTheFigmaHomeFixtureThroughTheJournalClient() async {
        let viewModel = TodaySnapViewModel(client: VisualTestSupport.snapJournalClient)

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

    @Test
    func appliesASavedReceiptExactlyOnceToTheSharedTodayState() async {
        let viewModel = TodaySnapViewModel(client: VisualTestSupport.snapJournalClient)
        await viewModel.load()
        let receipt = SnapRecordReceipt(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            category: .food,
            amountWon: 18_900,
            localDay: "2026-06-03",
            createdAt: Date(timeIntervalSince1970: 1_786_582_800)
        )

        #expect(viewModel.apply(receipt))
        #expect(!viewModel.apply(receipt))

        guard case let .content(summary) = viewModel.state else {
            Issue.record("Expected updated Today content")
            return
        }
        #expect(summary.totalAmount == 62_100)
        #expect(summary.entries.count == 5)
        #expect(summary.featuredEntries.first?.id == receipt.id)
        #expect(summary.recentEntries.first?.id == receipt.id)
        #expect(summary.featuredEntries.first?.artwork == nil)
    }

    @Test
    func receiptForAnotherLocalDayReplacesTodayWithReceiptOnlySummary() async {
        let viewModel = TodaySnapViewModel(client: VisualTestSupport.snapJournalClient)
        await viewModel.load()

        let applied = viewModel.apply(SnapRecordReceipt(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            category: .food,
            amountWon: 18_900,
            localDay: "2026-08-13",
            createdAt: Date(timeIntervalSince1970: 1_786_582_800)
        ))

        #expect(applied)
        guard case let .content(summary) = viewModel.state else {
            Issue.record("Expected receipt-only Today content")
            return
        }
        #expect(summary.day == SnapDay(year: 2026, month: 8, day: 13, weekday: .thursday))
        #expect(summary.entries.map(\.id) == [UUID(uuidString: "22222222-2222-4222-8222-222222222222")!])
        #expect(summary.totalAmount == 18_900)
        #expect(summary.featuredEntryIDs == summary.recentEntryIDs)
    }

    @Test
    func appliesASavedReceiptWhenProductionTodayReadIsUnavailable() async {
        let viewModel = TodaySnapViewModel(client: FailingSnapJournalClient())
        await viewModel.load()

        let applied = viewModel.apply(SnapRecordReceipt(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            category: .cafe,
            amountWon: 5_200,
            localDay: "2026-08-13",
            createdAt: Date(timeIntervalSince1970: 1_786_582_800)
        ))

        #expect(applied)
        guard case let .content(summary) = viewModel.state else {
            Issue.record("Expected session-local Today content")
            return
        }
        #expect(summary.totalAmount == 5_200)
    }

    @Test
    func rejectsAMalformedReceiptDayWithoutCrashingOrShowingFakeContent() async {
        let viewModel = TodaySnapViewModel(client: FailingSnapJournalClient())
        await viewModel.load()

        let applied = viewModel.apply(SnapRecordReceipt(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            category: .cafe,
            amountWon: 5_200,
            localDay: "2026-99-99",
            createdAt: Date(timeIntervalSince1970: 1_786_582_800)
        ))

        #expect(!applied)
        #expect(viewModel.state == .failure)
    }

    @Test
    func inFlightTodayLoadCannotOverwriteASessionLocalReceipt() async {
        let client = SuspendedSnapJournalClient(summary: VisualTestSupport.homeSummary)
        let viewModel = TodaySnapViewModel(client: client)
        let load = Task { await viewModel.load() }
        await client.waitUntilFetchStarts()

        #expect(viewModel.apply(SnapRecordReceipt(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            category: .food,
            amountWon: 18_900,
            localDay: "2026-08-13",
            createdAt: Date(timeIntervalSince1970: 1_786_582_800)
        )))
        await client.release()
        await load.value

        guard case let .content(summary) = viewModel.state else {
            Issue.record("Expected the session-local receipt to survive the load")
            return
        }
        #expect(summary.day == SnapDay(year: 2026, month: 8, day: 13, weekday: .thursday))
        #expect(summary.entries.map(\.id) == [UUID(uuidString: "22222222-2222-4222-8222-222222222222")!])
    }

    private func assertInvalidAmount(
        _ value: Int64,
        expected: SnapModelError = .nonPositiveAmount
    ) {
        do {
            _ = try KrwAmount(value)
            Issue.record("Expected \(value) KRW to be rejected")
        } catch {
            #expect(error as? SnapModelError == expected)
        }
    }
}

private struct FailingSnapJournalClient: SnapJournalClient {
    func fetchToday() async throws -> TodaySnapSummary {
        throw FixtureError.unavailable
    }

    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt {
        throw FixtureError.unavailable
    }
}

private enum FixtureError: Error {
    case unavailable
}

private actor SuspendedSnapJournalClient: SnapJournalClient {
    let summary: TodaySnapSummary
    private var fetchStarted = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var gate: CheckedContinuation<Void, Never>?

    init(summary: TodaySnapSummary) { self.summary = summary }

    func fetchToday() async throws -> TodaySnapSummary {
        fetchStarted = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        await withCheckedContinuation { gate = $0 }
        return summary
    }

    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt {
        throw FixtureError.unavailable
    }

    func waitUntilFetchStarts() async {
        guard !fetchStarted else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func release() {
        gate?.resume()
        gate = nil
    }
}

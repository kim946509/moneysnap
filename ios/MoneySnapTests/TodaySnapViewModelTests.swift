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
    func placeholderCanvasSizeStillScalesByAmount() throws {
        let larger = TodaySnapEntry(
            id: UUID(),
            category: .living,
            amount: try KrwAmount(18_900)
        )
        let smaller = TodaySnapEntry(
            id: UUID(),
            category: .transportation,
            amount: try KrwAmount(2_800)
        )
        let largest = TodayCanvasLayout.imageSize(for: larger, maximumAmount: larger.amount)
        let reduced = TodayCanvasLayout.imageSize(for: smaller, maximumAmount: larger.amount)

        #expect(largest == CGSize(width: 144, height: 144))
        #expect(reduced.width == 104)
        #expect(reduced.height == 104)
        #expect(reduced.width < largest.width)
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
    func emptyCanonicalTodayShowsZeroTotalCanvas() async {
        let viewModel = TodaySnapViewModel(client: EmptySnapJournalClient())

        await viewModel.load()

        guard case let .content(summary) = viewModel.state else {
            Issue.record("Expected an empty Home canvas with a zero total")
            return
        }
        #expect(summary.day == SnapDay(year: 2026, month: 8, day: 14, weekday: .friday))
        #expect(summary.entries.isEmpty)
        #expect(summary.totalAmount == 0)
        #expect(!viewModel.refreshFailure)
    }

    @Test
    func applyKeepsLocalJpegOnTheSessionHomeCanvas() async {
        let viewModel = TodaySnapViewModel(client: EmptySnapJournalClient())
        await viewModel.load()
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0x01])

        #expect(viewModel.apply(
            SnapRecordReceipt(
                id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
                category: .food,
                amountWon: 18_900,
                localDay: "2026-08-14",
                createdAt: Date(timeIntervalSince1970: 1_786_582_800),
                imageRef: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
            ),
            previewJPEG: jpeg
        ))

        guard case let .content(summary) = viewModel.state else {
            Issue.record("Expected Home content after applying a photographed Snap")
            return
        }
        #expect(summary.featuredEntries.first?.previewJPEG == jpeg)
        #expect(summary.featuredEntries.first?.artwork == nil)
    }

    @Test
    func hydratesTodayPhotosThroughTheMediaClient() async {
        let imageRef = UUID(uuidString: "018f1e2d-cccc-7abc-8def-0123456789ab")!
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0x02])
        let viewModel = TodaySnapViewModel(
            client: PhotoTodayClient(imageRef: imageRef),
            media: StubMediaClient(jpeg: jpeg)
        )

        await viewModel.load()

        guard case let .content(summary) = viewModel.state else {
            Issue.record("Expected hydrated Home content")
            return
        }
        #expect(summary.entries.first?.imageRef == imageRef)
        #expect(summary.entries.first?.previewJPEG == jpeg)
    }

    @Test
    func refreshFailureKeepsExistingContent() async {
        let client = FlakyTodayClient(summary: VisualTestSupport.homeSummary)
        let viewModel = TodaySnapViewModel(client: client)
        await viewModel.load()
        await client.failNextFetch()

        await viewModel.refresh()

        guard case .content = viewModel.state else {
            Issue.record("Expected existing content to remain")
            return
        }
        #expect(viewModel.refreshFailure)
    }

    @Test
    func refreshAfterReceiptReplacesHomeWithoutDuplicatingTheReceipt() async throws {
        let client = RecordingTodayClient(summary: VisualTestSupport.homeSummary)
        let viewModel = TodaySnapViewModel(client: client)
        await viewModel.load()
        let receipt = SnapRecordReceipt(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            category: .food,
            amountWon: 18_900,
            localDay: "2026-06-03",
            createdAt: Date(timeIntervalSince1970: 1_786_582_800)
        )
        #expect(viewModel.apply(receipt))
        try await client.include(receipt)
        await viewModel.refresh()

        guard case let .content(summary) = viewModel.state else {
            Issue.record("Expected canonical refresh content")
            return
        }
        #expect(summary.entries.filter { $0.id == receipt.id }.count == 1)
        #expect(summary.totalAmount == 62_100)
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

private struct EmptySnapJournalClient: SnapJournalClient {
    func fetchToday() async throws -> TodaySnapSummary {
        try TodaySnapSummary(
            day: SnapDay(year: 2026, month: 8, day: 14, weekday: .friday),
            entries: [],
            featuredEntryIDs: [],
            recentEntryIDs: []
        )
    }

    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt {
        throw FixtureError.unavailable
    }
}

private actor FlakyTodayClient: SnapJournalClient {
    let summary: TodaySnapSummary
    private var shouldFail = false

    init(summary: TodaySnapSummary) { self.summary = summary }

    func failNextFetch() { shouldFail = true }

    func fetchToday() async throws -> TodaySnapSummary {
        if shouldFail {
            shouldFail = false
            throw FixtureError.unavailable
        }
        return summary
    }

    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt {
        throw FixtureError.unavailable
    }
}

private actor RecordingTodayClient: SnapJournalClient {
    private var summary: TodaySnapSummary

    init(summary: TodaySnapSummary) { self.summary = summary }

    func include(_ receipt: SnapRecordReceipt) throws {
        let entry = TodaySnapEntry(
            id: receipt.id,
            category: receipt.category,
            amount: try KrwAmount(receipt.amountWon),
            artwork: nil
        )
        summary = try TodaySnapSummary(
            day: summary.day,
            entries: summary.entries + [entry],
            featuredEntryIDs: [entry.id] + summary.featuredEntryIDs,
            recentEntryIDs: [entry.id] + summary.recentEntryIDs
        )
    }

    func fetchToday() async throws -> TodaySnapSummary { summary }

    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt {
        throw FixtureError.unavailable
    }
}

private struct PhotoTodayClient: SnapJournalClient {
    let imageRef: UUID

    func fetchToday() async throws -> TodaySnapSummary {
        try TodaySnapSummary(
            day: SnapDay(year: 2026, month: 8, day: 14, weekday: .friday),
            entries: [
                TodaySnapEntry(
                    id: UUID(uuidString: "018f1e2d-1234-7abc-8def-0123456789ab")!,
                    category: .food,
                    amount: try KrwAmount(100),
                    imageRef: imageRef
                )
            ],
            featuredEntryIDs: [UUID(uuidString: "018f1e2d-1234-7abc-8def-0123456789ab")!],
            recentEntryIDs: [UUID(uuidString: "018f1e2d-1234-7abc-8def-0123456789ab")!]
        )
    }

    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt {
        throw FixtureError.unavailable
    }
}

private struct StubMediaClient: MediaClient {
    let jpeg: Data

    func publish(_ jpeg: NormalizedJpeg) async throws -> UUID {
        _ = jpeg
        throw FixtureError.unavailable
    }

    func fetchJPEG(_ imageRef: UUID) async throws -> Data {
        _ = imageRef
        return jpeg
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

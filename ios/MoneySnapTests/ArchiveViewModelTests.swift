import Foundation
import Testing
@testable import MoneySnap

struct ArchiveCalendarTests {
    @Test
    func june2026SundayGridPlacesTheFirstOnMonday() {
        let cells = ArchiveCalendar.cells(for: date("2026-06-01"), calendar: utcGregorian)

        #expect(cells.prefix(1).allSatisfy(\.isPadding))
        #expect(cells[1] == .day(localDay: "2026-06-01", dayNumber: 1))
        #expect(cells[3] == .day(localDay: "2026-06-03", dayNumber: 3))
        #expect(cells.filter { !$0.isPadding }.count == 30)
        #expect(cells.count == 35)
        #expect(ArchiveCalendar.weekdaySymbols == ["일", "월", "화", "수", "목", "금", "토"])
    }
}

@MainActor
struct ArchiveViewModelTests {
    @Test
    func loadsOccupiedDaysAndSelectsTodayInTheVisibleMonth() async {
        let client = RecordingArchiveClient(
            occupied: ["2026-06-03", "2026-06-14"],
            snaps: [Self.foodEntry]
        )
        let viewModel = ArchiveViewModel(
            client: client,
            now: { date("2026-06-03") },
            calendar: utcGregorian
        )

        await viewModel.load()

        #expect(viewModel.occupied == Set(["2026-06-03", "2026-06-14"]))
        #expect(viewModel.selectedDay == "2026-06-03")
        #expect(viewModel.snaps.map(\.id) == [ArchiveViewModelTests.foodEntry.id])
        #expect(viewModel.selectedDayTotal == 18_900)
        #expect(viewModel.emptyCopy == nil)
        #expect(viewModel.monthTitle == "2026년 6월")
        #expect(await client.ranges == [("2026-06-01", "2026-06-30"), ("2026-06-03", "2026-06-03")])
    }

    @Test
    func distinguishesAMonthWithNoSnapsFromAnEmptySelectedDay() async {
        let emptyMonth = ArchiveViewModel(
            client: RecordingArchiveClient(occupied: [], snaps: []),
            now: { date("2026-06-03") },
            calendar: utcGregorian
        )
        await emptyMonth.load()
        #expect(emptyMonth.emptyCopy == .emptyMonth)

        let emptyDay = ArchiveViewModel(
            client: RecordingArchiveClient(occupied: ["2026-06-14"], snaps: []),
            now: { date("2026-06-03") },
            calendar: utcGregorian
        )
        await emptyDay.load()
        #expect(emptyDay.selectedDay == "2026-06-03")
        #expect(emptyDay.emptyCopy == .emptySelectedDay)
    }

    @Test
    func shiftingMonthRequestsTheNewInclusiveRange() async {
        let client = RecordingArchiveClient(occupied: ["2026-07-01"], snaps: [])
        let viewModel = ArchiveViewModel(
            client: client,
            now: { date("2026-06-03") },
            calendar: utcGregorian
        )
        await viewModel.load()
        await viewModel.shiftMonth(1)

        #expect(viewModel.monthTitle == "2026년 7월")
        #expect(viewModel.selectedDay == "2026-07-01")
        #expect(await client.ranges.contains { $0 == ("2026-07-01", "2026-07-31") })
    }

    private static let foodEntry = TodaySnapEntry(
        id: UUID(uuidString: "FEED0000-0000-4000-8000-000000000001")!,
        category: .food,
        amount: try! KrwAmount(18_900)
    )
}

private let utcGregorian: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.locale = Locale(identifier: "ko_KR")
    calendar.firstWeekday = 1
    return calendar
}()

private func date(_ localDay: String) -> Date {
    let formatter = DateFormatter()
    formatter.calendar = utcGregorian
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: localDay)!
}

private actor RecordingArchiveClient: SnapJournalClient {
    let occupied: [String]
    let snaps: [TodaySnapEntry]
    private(set) var ranges: [(String, String)] = []

    init(occupied: [String], snaps: [TodaySnapEntry]) {
        self.occupied = occupied
        self.snaps = snaps
    }

    func fetchToday() async throws -> TodaySnapSummary {
        throw SnapJournalClientError.unavailable
    }

    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt {
        throw SnapRecordError.transportFailure
    }

    func archive(from: String, to: String, cursor: String?) async throws -> ArchivePage {
        ranges.append((from, to))
        let daySnaps = from == to ? snaps : []
        return ArchivePage(
            snaps: daySnaps,
            nextCursor: nil,
            occupiedLocalDays: from == to ? nil : occupied
        )
    }
}

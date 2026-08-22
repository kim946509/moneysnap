import Foundation
import Observation

@MainActor
@Observable
final class ArchiveViewModel {
    enum EmptyCopy: Equatable, Sendable {
        case emptyMonth
        case emptySelectedDay

        var message: String {
            switch self {
            case .emptyMonth: "이번 달 기록이 없어요"
            case .emptySelectedDay: "이 날에는 기록이 없어요"
            }
        }
    }

    private(set) var month: Date
    private(set) var selectedDay: String?
    private(set) var occupied: Set<String> = []
    private(set) var snaps: [TodaySnapEntry] = []
    private(set) var failed = false
    private(set) var isLoading = false

    private let client: any SnapJournalClient
    private let now: @Sendable () -> Date
    let calendar: Calendar

    init(
        client: any SnapJournalClient,
        now: @escaping @Sendable () -> Date = Date.init,
        calendar: Calendar = ArchiveViewModel.displayCalendar
    ) {
        self.client = client
        self.now = now
        self.calendar = calendar
        self.month = now()
    }

    var cells: [ArchiveDayCell] {
        ArchiveCalendar.cells(for: month, calendar: calendar)
    }

    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: month)
    }

    var selectedDayLabel: String {
        guard let selectedDay, let day = SnapDay.parse(localDay: selectedDay) else { return "" }
        return day.displayLabel
    }

    var selectedDayTotal: Int64 {
        snaps.reduce(0) { $0 + $1.amount.value }
    }

    var emptyCopy: EmptyCopy? {
        if failed { return nil }
        if occupied.isEmpty && snaps.isEmpty { return .emptyMonth }
        if snaps.isEmpty { return .emptySelectedDay }
        return nil
    }

    func load() async {
        selectedDay = ArchiveCalendar.isoDay(now(), calendar: calendar)
        if !cells.contains(where: { cell in
            if case let .day(localDay, _) = cell { return localDay == selectedDay }
            return false
        }) {
            selectedDay = cells.compactMap { cell in
                if case let .day(localDay, _) = cell { return localDay }
                return nil
            }.first
        }
        await loadMonth()
    }

    func shiftMonth(_ value: Int) async {
        guard let next = calendar.date(byAdding: .month, value: value, to: month) else { return }
        month = next
        selectedDay = ArchiveCalendar.monthBounds(for: next, calendar: calendar)?.from
        await loadMonth()
    }

    func select(day localDay: String) async {
        selectedDay = localDay
        await loadDay(localDay)
    }

    func retry() async {
        await loadMonth()
    }

    private func loadMonth() async {
        guard let bounds = ArchiveCalendar.monthBounds(for: month, calendar: calendar) else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await client.archive(from: bounds.from, to: bounds.to, cursor: nil)
            occupied = Set(page.occupiedLocalDays ?? [])
            failed = false
            if let selectedDay {
                await loadDay(selectedDay)
            }
        } catch {
            failed = true
        }
    }

    private func loadDay(_ day: String) async {
        do {
            let page = try await client.archive(from: day, to: day, cursor: nil)
            snaps = page.snaps
            failed = false
        } catch {
            failed = true
        }
    }

    static var displayCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.firstWeekday = 1
        if TimeZone.current.identifier.contains("/") || TimeZone.current.identifier == "UTC" {
            calendar.timeZone = .current
        } else {
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        }
        return calendar
    }
}

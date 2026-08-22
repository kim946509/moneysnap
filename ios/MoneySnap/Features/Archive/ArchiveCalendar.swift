import Foundation

enum ArchiveDayCell: Equatable, Sendable {
    case padding
    case day(localDay: String, dayNumber: Int)

    var isPadding: Bool {
        if case .padding = self { return true }
        return false
    }
}

enum ArchiveCalendar {
    static let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

    static func cells(for month: Date, calendar: Calendar) -> [ArchiveDayCell] {
        var calendar = calendar
        calendar.firstWeekday = 1
        guard
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
            let range = calendar.range(of: .day, in: .month, for: start)
        else {
            return []
        }
        let weekday = calendar.component(.weekday, from: start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells = Array(repeating: ArchiveDayCell.padding, count: leading)
        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: start) else { continue }
            cells.append(.day(localDay: isoDay(date, calendar: calendar), dayNumber: day))
        }
        while !cells.isEmpty && cells.count % 7 != 0 {
            cells.append(.padding)
        }
        return cells
    }

    static func monthBounds(for month: Date, calendar: Calendar) -> (from: String, to: String)? {
        guard
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
            let range = calendar.range(of: .day, in: .month, for: start),
            let end = calendar.date(byAdding: .day, value: range.count - 1, to: start)
        else {
            return nil
        }
        return (isoDay(start, calendar: calendar), isoDay(end, calendar: calendar))
    }

    static func isoDay(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

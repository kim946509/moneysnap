import Foundation

enum SnapModelError: Error, Equatable {
    case nonPositiveAmount
    case amountAboveLimit
}

struct KrwAmount: Equatable, Comparable, Sendable {
    let value: Int64

    init(_ value: Int64) throws {
        guard value > 0 else {
            throw SnapModelError.nonPositiveAmount
        }
        guard value <= 999_999_999 else {
            throw SnapModelError.amountAboveLimit
        }
        self.value = value
    }

    static func < (lhs: KrwAmount, rhs: KrwAmount) -> Bool {
        lhs.value < rhs.value
    }
}

enum SnapCategory: String, CaseIterable, Codable, Equatable, Sendable {
    case food
    case cafe
    case transportation
    case shopping
    case living
    case culture
    case health
    case other

    var title: String {
        switch self {
        case .food: "식비"
        case .cafe: "카페"
        case .transportation: "교통"
        case .shopping: "쇼핑"
        case .living: "생활"
        case .culture: "문화"
        case .health: "건강"
        case .other: "기타"
        }
    }
}

struct SnapDay: Equatable, Sendable {
    enum Weekday: String, Equatable, Sendable {
        case sunday = "일요일"
        case monday = "월요일"
        case tuesday = "화요일"
        case wednesday = "수요일"
        case thursday = "목요일"
        case friday = "금요일"
        case saturday = "토요일"
    }

    let year: Int
    let month: Int
    let day: Int
    let weekday: Weekday

    var displayLabel: String {
        "\(month)월 \(day)일 \(weekday.rawValue)"
    }

    static func parse(localDay: String) -> SnapDay? {
        let parts = localDay.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(
            year: parts[0], month: parts[1], day: parts[2]
        )) else { return nil }
        let normalized = calendar.dateComponents([.year, .month, .day], from: date)
        guard normalized.year == parts[0], normalized.month == parts[1],
              normalized.day == parts[2] else { return nil }
        let weekdays: [SnapDay.Weekday] = [
            .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday
        ]
        return SnapDay(
            year: parts[0], month: parts[1], day: parts[2],
            weekday: weekdays[calendar.component(.weekday, from: date) - 1]
        )
    }
}

enum SnapArtwork: String, Equatable, Sendable {
    case food = "FoodSnap"
    case cafe = "CafeSnap"

    var canvasAspectRatio: CGFloat {
        switch self {
        case .food: 4 / 3
        case .cafe: 81 / 108
        }
    }

    var canvasLongestSide: CGFloat {
        switch self {
        case .food: 144
        case .cafe: 150
        }
    }
}

struct TodaySnapEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let category: SnapCategory
    let amount: KrwAmount
    let artwork: SnapArtwork?
    let imageRef: UUID?
    let previewJPEG: Data?
    let revealsAmount: Bool

    init(
        id: UUID,
        category: SnapCategory,
        amount: KrwAmount,
        artwork: SnapArtwork? = nil,
        imageRef: UUID? = nil,
        previewJPEG: Data? = nil,
        revealsAmount: Bool = true
    ) {
        self.id = id
        self.category = category
        self.amount = amount
        self.artwork = artwork
        self.imageRef = imageRef
        self.previewJPEG = previewJPEG
        self.revealsAmount = revealsAmount
    }
}

struct SnapDetailPresentation: Equatable, Sendable {
    let entry: TodaySnapEntry
    let day: SnapDay
}

struct TodaySnapSummary: Equatable, Sendable {
    let day: SnapDay
    let entries: [TodaySnapEntry]
    let featuredEntryIDs: [TodaySnapEntry.ID]
    let recentEntryIDs: [TodaySnapEntry.ID]
    let totalAmount: Int64

    init(
        day: SnapDay,
        entries: [TodaySnapEntry],
        featuredEntryIDs: [TodaySnapEntry.ID],
        recentEntryIDs: [TodaySnapEntry.ID]
    ) throws {
        self.day = day
        self.entries = entries
        self.featuredEntryIDs = featuredEntryIDs
        self.recentEntryIDs = recentEntryIDs
        self.totalAmount = entries.reduce(0) { $0 + $1.amount.value }
    }

    var featuredEntries: [TodaySnapEntry] {
        entries.ordered(by: featuredEntryIDs)
    }

    var recentEntries: [TodaySnapEntry] {
        entries.ordered(by: recentEntryIDs)
    }
}

private extension Array where Element == TodaySnapEntry {
    func ordered(by identifiers: [TodaySnapEntry.ID]) -> [TodaySnapEntry] {
        identifiers.compactMap { identifier in
            first { $0.id == identifier }
        }
    }
}

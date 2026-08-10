import Foundation

enum SnapModelError: Error, Equatable {
    case nonPositiveAmount
    case totalOverflow
}

struct KrwAmount: Equatable, Comparable, Sendable {
    let value: Int64

    init(_ value: Int64) throws {
        guard value > 0 else {
            throw SnapModelError.nonPositiveAmount
        }
        self.value = value
    }

    static func < (lhs: KrwAmount, rhs: KrwAmount) -> Bool {
        lhs.value < rhs.value
    }
}

enum SnapCategory: String, CaseIterable, Equatable, Sendable {
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
        case wednesday = "수요일"
    }

    let year: Int
    let month: Int
    let day: Int
    let weekday: Weekday

    var displayLabel: String {
        "\(month)월 \(day)일 \(weekday.rawValue)"
    }

    static let figmaReference = SnapDay(year: 2026, month: 6, day: 3, weekday: .wednesday)
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
        var total: Int64 = 0
        for entry in entries {
            let addition = total.addingReportingOverflow(entry.amount.value)
            guard !addition.overflow else {
                throw SnapModelError.totalOverflow
            }
            total = addition.partialValue
        }

        self.day = day
        self.entries = entries
        self.featuredEntryIDs = featuredEntryIDs
        self.recentEntryIDs = recentEntryIDs
        self.totalAmount = total
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

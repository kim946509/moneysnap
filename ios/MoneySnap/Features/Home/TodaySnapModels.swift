import Foundation

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

struct TodaySnapEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let category: SnapCategory
    let amount: Int64
    let imageName: String?
}

struct TodaySnapSummary: Equatable, Sendable {
    let dateLabel: String
    let entries: [TodaySnapEntry]
    let featuredEntryIDs: [TodaySnapEntry.ID]
    let recentEntryIDs: [TodaySnapEntry.ID]

    var totalAmount: Int64 {
        entries.reduce(0) { $0 + $1.amount }
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

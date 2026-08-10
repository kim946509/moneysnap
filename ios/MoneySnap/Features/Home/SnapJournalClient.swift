import Foundation

protocol SnapJournalClient: Sendable {
    func fetchToday() async throws -> TodaySnapSummary
}

struct InMemorySnapJournalClient: SnapJournalClient {
    let summary: TodaySnapSummary

    func fetchToday() async throws -> TodaySnapSummary {
        summary
    }
}

extension InMemorySnapJournalClient {
    static let fixture = InMemorySnapJournalClient(summary: .figmaHome)
}

extension TodaySnapSummary {
    static let figmaHome: TodaySnapSummary = {
        let foodID = UUID(uuidString: "FEED0000-0000-4000-8000-000000000001")!
        let cafeID = UUID(uuidString: "CAFE0000-0000-4000-8000-000000000002")!
        let transportationID = UUID(uuidString: "B0000000-0000-4000-8000-000000000003")!
        let livingID = UUID(uuidString: "B0000000-0000-4000-8000-000000000004")!

        return try! TodaySnapSummary(
            day: .figmaReference,
            entries: [
                TodaySnapEntry(id: foodID, category: .food, amount: try KrwAmount(18_900), artwork: .food),
                TodaySnapEntry(id: cafeID, category: .cafe, amount: try KrwAmount(5_200), artwork: .cafe),
                TodaySnapEntry(id: transportationID, category: .transportation, amount: try KrwAmount(2_800), artwork: nil),
                TodaySnapEntry(id: livingID, category: .living, amount: try KrwAmount(16_300), artwork: nil)
            ],
            featuredEntryIDs: [foodID, cafeID, transportationID],
            recentEntryIDs: [foodID, cafeID]
        )
    }()
}

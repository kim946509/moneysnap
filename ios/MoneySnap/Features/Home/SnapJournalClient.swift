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

        return TodaySnapSummary(
            dateLabel: "6월 3일 수요일",
            entries: [
                TodaySnapEntry(id: foodID, category: .food, amount: 18_900, imageName: "FoodSnap"),
                TodaySnapEntry(id: cafeID, category: .cafe, amount: 5_200, imageName: "CafeSnap"),
                TodaySnapEntry(id: transportationID, category: .transportation, amount: 2_800, imageName: nil),
                TodaySnapEntry(id: livingID, category: .living, amount: 16_300, imageName: nil)
            ],
            featuredEntryIDs: [foodID, cafeID, transportationID],
            recentEntryIDs: [foodID, cafeID]
        )
    }()
}

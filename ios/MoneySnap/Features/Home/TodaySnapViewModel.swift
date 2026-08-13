import Foundation
import Observation

@MainActor
@Observable
final class TodaySnapViewModel {
    enum State: Equatable {
        case loading
        case content(TodaySnapSummary)
        case failure
    }

    private(set) var state: State = .loading
    private let client: any SnapJournalClient
    private var didLoad = false
    private var appliedReceiptIDs: Set<UUID> = []

    init(client: any SnapJournalClient) {
        self.client = client
    }

    func load() async {
        guard !didLoad else { return }
        didLoad = true
        do {
            let summary = try await client.fetchToday()
            guard appliedReceiptIDs.isEmpty else { return }
            state = .content(summary)
        } catch {
            guard appliedReceiptIDs.isEmpty else { return }
            state = .failure
        }
    }

    @discardableResult
    func apply(_ receipt: SnapRecordReceipt) -> Bool {
        guard !appliedReceiptIDs.contains(receipt.id),
              let receiptDay = Self.day(from: receipt.localDay) else { return false }
        let entry: TodaySnapEntry
        do {
            entry = TodaySnapEntry(
                id: receipt.id,
                category: receipt.category,
                amount: try KrwAmount(receipt.amountWon),
                artwork: nil
            )
        } catch {
            return false
        }

        let summary: TodaySnapSummary
        do {
            switch state {
            case let .content(current):
                if current.day == receiptDay {
                    guard !current.entries.contains(where: { $0.id == receipt.id }) else { return false }
                    summary = try TodaySnapSummary(
                        day: current.day,
                        entries: current.entries + [entry],
                        featuredEntryIDs: [entry.id] + current.featuredEntryIDs,
                        recentEntryIDs: [entry.id] + current.recentEntryIDs
                    )
                } else {
                    summary = try TodaySnapSummary(
                        day: receiptDay,
                        entries: [entry],
                        featuredEntryIDs: [entry.id],
                        recentEntryIDs: [entry.id]
                    )
                }
            case .loading, .failure:
                summary = try TodaySnapSummary(
                    day: receiptDay,
                    entries: [entry],
                    featuredEntryIDs: [entry.id],
                    recentEntryIDs: [entry.id]
                )
            }
            state = .content(summary)
            appliedReceiptIDs.insert(receipt.id)
            return true
        } catch {
            return false
        }
    }

    private static func day(from localDay: String) -> SnapDay? {
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

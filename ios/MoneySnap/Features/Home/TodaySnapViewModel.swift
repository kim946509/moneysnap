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
    private(set) var refreshFailure = false
    private let client: any SnapJournalClient
    private let media: (any MediaClient)?
    private var didLoad = false
    private var appliedReceiptIDs: Set<UUID> = []
    private var requestGeneration = 0

    init(client: any SnapJournalClient, media: (any MediaClient)? = nil) {
        self.client = client
        self.media = media
    }

    func load() async {
        guard !didLoad else { return }
        didLoad = true
        await fetch(kind: .initial)
    }

    func refresh() async {
        await fetch(kind: .refresh)
    }

    func retry() async {
        await fetch(kind: state == .failure || state == .loading ? .initial : .refresh)
    }

    @discardableResult
    func apply(_ receipt: SnapRecordReceipt, previewJPEG: Data? = nil) -> Bool {
        guard !appliedReceiptIDs.contains(receipt.id),
              let receiptDay = Self.day(from: receipt.localDay) else { return false }
        let entry: TodaySnapEntry
        do {
            entry = TodaySnapEntry(
                id: receipt.id,
                category: receipt.category,
                amount: try KrwAmount(receipt.amountWon),
                imageRef: receipt.imageRef,
                previewJPEG: previewJPEG
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
            requestGeneration += 1
            return true
        } catch {
            return false
        }
    }

    private func fetch(kind: RequestKind) async {
        requestGeneration += 1
        let generation = requestGeneration
        do {
            let summary = try await hydrate(client.fetchToday())
            guard generation == requestGeneration else { return }
            if kind == .initial, !appliedReceiptIDs.isEmpty { return }
            state = .content(summary)
            appliedReceiptIDs.removeAll()
            refreshFailure = false
        } catch {
            guard generation == requestGeneration else { return }
            if kind == .initial, !appliedReceiptIDs.isEmpty { return }
            switch state {
            case .content:
                refreshFailure = true
            case .loading, .failure:
                state = .failure
            }
        }
    }

    func replace(_ detail: SnapDetail) {
        guard case let .content(current) = state,
              let amount = try? KrwAmount(detail.amountWon) else { return }
        let entries = current.entries.map { entry in
            entry.id == detail.id
                ? TodaySnapEntry(
                    id: entry.id,
                    category: detail.category,
                    amount: amount,
                    artwork: entry.artwork,
                    imageRef: detail.imageRef ?? entry.imageRef,
                    previewJPEG: entry.previewJPEG
                )
                : entry
        }
        if let summary = try? TodaySnapSummary(
            day: current.day,
            entries: entries,
            featuredEntryIDs: current.featuredEntryIDs,
            recentEntryIDs: current.recentEntryIDs
        ) {
            state = .content(summary)
        }
    }

    func remove(_ snapID: UUID) {
        guard case let .content(current) = state else { return }
        let entries = current.entries.filter { $0.id != snapID }
        if let summary = try? TodaySnapSummary(
            day: current.day,
            entries: entries,
            featuredEntryIDs: current.featuredEntryIDs.filter { $0 != snapID },
            recentEntryIDs: current.recentEntryIDs.filter { $0 != snapID }
        ) {
            state = .content(summary)
        }
    }

    private func hydrate(_ summary: TodaySnapSummary) async -> TodaySnapSummary {
        guard let media else { return summary }
        var jpegs: [UUID: Data] = [:]
        await withTaskGroup(of: (UUID, Data?).self) { group in
            for entry in summary.entries {
                guard let imageRef = entry.imageRef, entry.previewJPEG == nil else { continue }
                group.addTask {
                    (entry.id, try? await media.fetchJPEG(imageRef))
                }
            }
            for await (id, jpeg) in group {
                if let jpeg {
                    jpegs[id] = jpeg
                }
            }
        }
        guard !jpegs.isEmpty else { return summary }
        let entries = summary.entries.map { entry in
            guard let jpeg = jpegs[entry.id] else { return entry }
            return TodaySnapEntry(
                id: entry.id,
                category: entry.category,
                amount: entry.amount,
                artwork: entry.artwork,
                imageRef: entry.imageRef,
                previewJPEG: jpeg
            )
        }
        return (try? TodaySnapSummary(
            day: summary.day,
            entries: entries,
            featuredEntryIDs: summary.featuredEntryIDs,
            recentEntryIDs: summary.recentEntryIDs
        )) ?? summary
    }

    private static func day(from localDay: String) -> SnapDay? {
        SnapDay.parse(localDay: localDay)
    }

    private enum RequestKind {
        case initial
        case refresh
    }
}

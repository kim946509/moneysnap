import Foundation
import Testing
@testable import MoneySnap

@MainActor
struct SnapDetailModelTests {
    @Test
    func selectingACategoryRevisesWithoutAnExplicitSave() async {
        let client = RecordingSnapJournal()
        let model = SnapDetailModel(
            snapID: client.detail.id,
            client: client,
            mutationID: { UUID(uuidString: "11111111-1111-4111-8111-111111111111")! }
        )
        await model.load()

        await model.selectCategory(.cafe)

        #expect(client.reviseCalls.count == 1)
        #expect(client.reviseCalls.first?.command.category == .cafe)
        #expect(client.reviseCalls.first?.command.amountWon == 18_900)
        if case let .content(detail) = model.state {
            #expect(detail.category == .cafe)
        } else {
            Issue.record("expected content after category commit")
        }
    }

    @Test
    func committingTheSameDraftDoesNotRevise() async {
        let client = RecordingSnapJournal()
        let model = SnapDetailModel(snapID: client.detail.id, client: client)
        await model.load()

        await model.commitDraft()

        #expect(client.reviseCalls.isEmpty)
    }

    @Test
    func invalidAmountDoesNotRevise() async {
        let client = RecordingSnapJournal()
        let model = SnapDetailModel(snapID: client.detail.id, client: client)
        await model.load()
        model.draftAmount = "0"

        await model.commitDraft()

        #expect(client.reviseCalls.isEmpty)
        #expect(model.draftAmount == "0")
    }
}

@MainActor
private final class RecordingSnapJournal: SnapJournalClient {
    var detail = SnapDetail(
        id: UUID(uuidString: "018f1e2d-1234-7abc-8def-0123456789ab")!,
        category: .food,
        amountWon: 18_900,
        localDay: "2026-08-14",
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1),
        version: 1
    )
    private(set) var reviseCalls: [(snapID: UUID, command: SnapReviseCommand)] = []

    func fetchToday() async throws -> TodaySnapSummary {
        throw SnapJournalClientError.unavailable
    }

    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt {
        throw SnapJournalClientError.unavailable
    }

    func get(_ snapID: UUID) async throws -> SnapDetail {
        detail
    }

    func revise(snapID: UUID, command: SnapReviseCommand) async throws -> SnapDetail {
        reviseCalls.append((snapID, command))
        detail = SnapDetail(
            id: detail.id,
            category: command.category,
            amountWon: command.amountWon,
            localDay: detail.localDay,
            createdAt: detail.createdAt,
            updatedAt: Date(timeIntervalSince1970: 2),
            version: detail.version + 1,
            imageRef: detail.imageRef
        )
        return detail
    }

    func delete(snapID: UUID, mutationID: String) async throws {}

    func archive(from: String, to: String, cursor: String?) async throws -> ArchivePage {
        throw SnapJournalClientError.unavailable
    }
}

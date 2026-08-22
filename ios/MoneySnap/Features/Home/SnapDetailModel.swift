import Foundation
import Observation

@MainActor
@Observable
final class SnapDetailModel {
    enum State: Equatable {
        case loading
        case content(SnapDetail)
        case failure
        case gone
    }

    private(set) var state: State = .loading
    private(set) var isSaving = false
    private(set) var isDeleting = false
    private(set) var failure: SnapRecordError?
    private(set) var previewJPEG: Data?
    var draftCategory: SnapCategory?
    var draftAmount: String = ""
    private var frozenRevise: SnapReviseCommand?
    private var frozenDeleteMutation: String?
    private let snapID: UUID
    private let client: any SnapJournalClient
    private let media: (any MediaClient)?
    private let mutationID: @Sendable () -> UUID

    init(
        snapID: UUID,
        client: any SnapJournalClient,
        media: (any MediaClient)? = nil,
        mutationID: @escaping @Sendable () -> UUID = UUID.init
    ) {
        self.snapID = snapID
        self.client = client
        self.media = media
        self.mutationID = mutationID
    }

    func load() async {
        do {
            let detail = try await client.get(snapID)
            state = .content(detail)
            draftCategory = detail.category
            draftAmount = String(detail.amountWon)
            failure = nil
            if let imageRef = detail.imageRef, let media {
                previewJPEG = try? await media.fetchJPEG(imageRef)
            } else {
                previewJPEG = nil
            }
        } catch let error as SnapRecordError where error.isGone {
            state = .gone
        } catch {
            state = .failure
        }
    }

    func save() async -> SnapDetail? {
        guard !isSaving, let category = draftCategory,
              let amount = Int64(draftAmount),
              case let .content(current) = state else { return nil }
        let command = frozenRevise ?? SnapReviseCommand(
            clientMutationId: mutationID().uuidString.lowercased(),
            expectedVersion: current.version,
            category: category,
            amountWon: amount
        )
        frozenRevise = command
        isSaving = true
        defer { isSaving = false }
        do {
            let detail = try await client.revise(snapID: snapID, command: command)
            state = .content(detail)
            draftCategory = detail.category
            draftAmount = String(detail.amountWon)
            frozenRevise = nil
            failure = nil
            return detail
        } catch let error as SnapRecordError {
            failure = error
            if error.isGone { state = .gone }
            return nil
        } catch {
            failure = .transportFailure
            return nil
        }
    }

    func delete() async -> Bool {
        guard !isDeleting else { return false }
        let mutation = frozenDeleteMutation ?? mutationID().uuidString.lowercased()
        frozenDeleteMutation = mutation
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await client.delete(snapID: snapID, mutationID: mutation)
            state = .gone
            failure = nil
            return true
        } catch let error as SnapRecordError {
            failure = error
            if error.isGone { state = .gone }
            return false
        } catch {
            failure = .transportFailure
            return false
        }
    }
}

private extension SnapRecordError {
    var isGone: Bool {
        if case .notAccessible = self { return true }
        return false
    }
}

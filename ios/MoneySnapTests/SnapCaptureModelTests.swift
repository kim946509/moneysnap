import Foundation
import Testing
@testable import MoneySnap

@MainActor
struct SnapCaptureModelTests {
    @Test
    func categoryAndAmountStayTogetherOnTheCombinedSheet() {
        let model = makeModel()

        #expect(model.phase == .details)
        model.select(.food)
        #expect(model.phase == .details)
        model.appendDigit(1)
        model.appendDigit(8)
        model.goBack()

        #expect(model.phase == .details)
        #expect(model.selectedCategory == .food)
        #expect(model.amountText == "₩18")
        #expect(model.accessibilityAnnouncement == "카테고리와 금액 입력")
    }

    @Test
    func stagedCategoryAndAmountDraftSurviveBackNavigation() {
        let model = makeModel(layout: .staged)

        model.select(.food)
        #expect(model.phase == .amount)
        model.appendDigit(1)
        model.appendDigit(8)
        model.goBack()

        #expect(model.phase == .category)
        #expect(model.focusTarget == .categoryHeader)
        #expect(model.accessibilityAnnouncement == "카테고리 선택 단계")
        #expect(model.selectedCategory == .food)
        #expect(model.amountText == "₩18")

        model.select(.food)
        #expect(model.phase == .amount)
        #expect(model.focusTarget == .amountHeader)
        #expect(model.accessibilityAnnouncement == "금액 입력 단계")
        #expect(model.amountText == "₩18")
    }

    @Test
    func digitBufferRejectsLeadingZeroZeroAndAmountsAboveTheLimit() {
        let model = makeModel()
        model.select(.food)

        model.appendDigit(0)
        #expect(model.amountText == "₩0")
        #expect(!model.canSubmit)

        for digit in [9, 9, 9, 9, 9, 9, 9, 9, 9, 9] {
            model.appendDigit(digit)
        }

        #expect(model.amountText == "₩999,999,999")
        #expect(model.canSubmit)
    }

    @Test
    func firstSubmitFreezesOneCommandAndDuplicateTapDoesNotRecordTwice() async throws {
        let journal = RecordingSnapJournalClient(gatedResult: .success(.fixture))
        let model = makeModel(journal: journal)
        enterValidAmount(in: model)

        let first = Task { await model.submit() }
        await journal.waitUntilRecordStarts()
        #expect(await model.submit() == nil)
        await journal.release()
        #expect(await first.value == .fixture)

        let commands = await journal.commands
        #expect(commands.count == 1)
        #expect(commands.first?.clientMutationId == "11111111-1111-4111-8111-111111111111")
        #expect(commands.first?.localDay == "2026-08-13")
        #expect(commands.first?.timeZone == "Asia/Seoul")
        #expect(commands.first?.amountWon == 18_900)
    }

    @Test
    func commitUnknownRetryUsesTheSameFrozenCommand() async {
        let journal = RecordingSnapJournalClient(
            results: [.failure(.transportFailure), .success(.fixture)]
        )
        let model = makeModel(journal: journal)
        enterValidAmount(in: model)

        #expect(await model.submit() == nil)
        #expect(model.failure == .transportFailure)
        #expect(await model.submit() == .fixture)

        let commands = await journal.commands
        #expect(commands.count == 2)
        #expect(commands[0] == commands[1])
        #expect(!model.requiresAbandonConfirmation)
    }

    @Test
    func zeroOffsetGMTIsNormalizedToUTC() async {
        let journal = RecordingSnapJournalClient(result: .success(.fixture))
        let model = SnapCaptureModel(
            record: journal.record,
            now: { Date(timeIntervalSince1970: 1_786_582_800) },
            timeZone: { TimeZone(identifier: "GMT")! },
            mutationID: { UUID(uuidString: "11111111-1111-4111-8111-111111111111")! }
        )
        enterValidAmount(in: model)

        _ = await model.submit()

        #expect(await journal.commands.first?.timeZone == "UTC")
    }

    @Test
    func fixedNumericOffsetDoesNotEmitARejectedServerCommand() async {
        let journal = RecordingSnapJournalClient(result: .success(.fixture))
        let model = SnapCaptureModel(
            record: journal.record,
            now: { Date(timeIntervalSince1970: 1_786_582_800) },
            timeZone: { TimeZone(secondsFromGMT: 9 * 60 * 60)! },
            mutationID: { UUID(uuidString: "11111111-1111-4111-8111-111111111111")! }
        )
        enterValidAmount(in: model)

        #expect(await model.submit() == nil)
        #expect(await journal.commands.isEmpty)
    }

    @Test
    func attachStartsPhotoPublishBeforeSubmit() async {
        let imageRef = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let publisher = GatedPhotoPublisher(imageRef: imageRef)
        let journal = RecordingSnapJournalClient(result: .success(.fixture))
        let model = makeModel(journal: journal, publishPhoto: publisher.publish)
        model.attach([
            NormalizedJpeg(bytes: Data([0xFF, 0xD8, 0xFF]), checksumSha256: "ab", width: 8, height: 8)
        ])

        await publisher.waitUntilStarted()
        #expect(await publisher.publishCount == 1)
        #expect(await journal.commands.isEmpty)

        enterValidAmount(in: model)
        let submit = Task { await model.submit() }
        await publisher.release()
        #expect(await submit.value != nil)
        #expect(await publisher.publishCount == 1)
        #expect(await journal.commands.first?.imageRef == imageRef)
    }

    @Test
    func attachedPhotoIsUploadedOnceAndFrozenOnRecordRetry() async {
        let imageRef = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let publisher = RecordingPhotoPublisher(imageRef: imageRef)
        let journal = RecordingSnapJournalClient(
            results: [.failure(.transportFailure), .success(.fixture)]
        )
        let model = makeModel(journal: journal, publishPhoto: publisher.publish)
        model.attach([
            NormalizedJpeg(bytes: Data([0xFF, 0xD8, 0xFF]), checksumSha256: "ab", width: 8, height: 8)
        ])
        enterValidAmount(in: model)

        #expect(await model.submit() == nil)
        #expect(await model.submit() == .fixture)

        #expect(await publisher.publishCount == 1)
        let commands = await journal.commands
        #expect(commands.count == 2)
        #expect(commands[0].imageRef == imageRef)
        #expect(commands[0] == commands[1])
    }

    @Test
    func photoLessRecordOmitsImageRef() async {
        let journal = RecordingSnapJournalClient(result: .success(.fixture))
        let model = makeModel(journal: journal)
        enterValidAmount(in: model)

        #expect(await model.submit() == .fixture)
        #expect(await journal.commands.first?.imageRef == nil)
    }

    @Test
    func knownShortAliasDoesNotEmitARejectedServerCommand() async {
        let journal = RecordingSnapJournalClient(result: .success(.fixture))
        let model = SnapCaptureModel(
            record: journal.record,
            now: { Date(timeIntervalSince1970: 1_786_582_800) },
            timeZone: { TimeZone(identifier: "EST")! },
            mutationID: { UUID(uuidString: "11111111-1111-4111-8111-111111111111")! }
        )
        enterValidAmount(in: model)

        #expect(!model.canSubmit)
        #expect(await model.submit() == nil)
        #expect(await journal.commands.isEmpty)
    }

    private func makeModel(
        journal: RecordingSnapJournalClient = RecordingSnapJournalClient(result: .success(.fixture)),
        layout: SnapCaptureModel.Layout = .combined,
        publishPhoto: (@Sendable (NormalizedJpeg) async throws -> UUID)? = nil
    ) -> SnapCaptureModel {
        SnapCaptureModel(
            record: journal.record,
            now: { Date(timeIntervalSince1970: 1_786_582_800) },
            timeZone: { TimeZone(identifier: "Asia/Seoul")! },
            mutationID: { UUID(uuidString: "11111111-1111-4111-8111-111111111111")! },
            layout: layout,
            publishPhoto: publishPhoto
        )
    }

    private func enterValidAmount(in model: SnapCaptureModel) {
        model.select(.food)
        [1, 8, 9, 0, 0].forEach(model.appendDigit)
    }
}

private actor GatedPhotoPublisher {
    private let imageRef: UUID
    private(set) var publishCount = 0
    private var started = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var gate: CheckedContinuation<Void, Never>?

    init(imageRef: UUID) {
        self.imageRef = imageRef
    }

    func publish(_ jpeg: NormalizedJpeg) async throws -> UUID {
        _ = jpeg
        publishCount += 1
        started = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        await withCheckedContinuation { gate = $0 }
        return imageRef
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func release() {
        gate?.resume()
        gate = nil
    }
}

private actor RecordingPhotoPublisher {
    private let imageRef: UUID
    private(set) var publishCount = 0

    init(imageRef: UUID) {
        self.imageRef = imageRef
    }

    func publish(_ jpeg: NormalizedJpeg) async throws -> UUID {
        publishCount += 1
        _ = jpeg
        return imageRef
    }
}

private actor RecordingSnapJournalClient {
    private(set) var commands: [SnapRecordCommand] = []
    private var results: [Result<SnapRecordReceipt, SnapRecordError>]
    private var gate: CheckedContinuation<Void, Never>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var started = false
    private var isGated = false

    init(result: Result<SnapRecordReceipt, SnapRecordError>) {
        results = [result]
    }

    init(results: [Result<SnapRecordReceipt, SnapRecordError>]) {
        self.results = results
    }

    init(gatedResult: Result<SnapRecordReceipt, SnapRecordError>) {
        results = [gatedResult]
        isGated = true
    }

    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt {
        commands.append(command)
        started = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        if isGated {
            await withCheckedContinuation { gate = $0 }
        }
        let result = results.removeFirst()
        return try result.get()
    }

    func waitUntilRecordStarts() async {
        guard !started else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func release() {
        gate?.resume()
        gate = nil
    }
}

private extension SnapRecordReceipt {
    static let fixture = SnapRecordReceipt(
        id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
        category: .food,
        amountWon: 18_900,
        localDay: "2026-08-13",
        createdAt: Date(timeIntervalSince1970: 1_786_582_800)
    )
}

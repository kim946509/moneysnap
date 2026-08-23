import Foundation
import Observation

@MainActor
@Observable
final class SnapCaptureModel {
    enum Layout: Equatable, Sendable {
        case staged
        case combined
    }

    enum Phase: Equatable, Sendable {
        case source
        case category
        case amount
        case details
    }

    enum FocusTarget: Hashable, Sendable {
        case sourceHeader
        case categoryHeader
        case amountHeader
        case retryAction
    }

    private(set) var layout: Layout
    private(set) var phase: Phase
    let photoQueue = PhotoQueueModel()
    private(set) var selectedCategory: SnapCategory?
    private(set) var failure: SnapRecordError?
    private(set) var isSubmitting = false
    private(set) var focusTarget: FocusTarget = .categoryHeader

    private var digits = ""
    private var frozenCommand: SnapRecordCommand?
    private var succeeded = false
    private var publishTask: Task<UUID, Error>?
    private let allowsPhotos: Bool
    private let record: @Sendable (SnapRecordCommand) async throws -> SnapRecordReceipt
    private let publishPhoto: (@Sendable (NormalizedJpeg) async throws -> UUID)?
    private let now: @Sendable () -> Date
    private let timeZone: @Sendable () -> TimeZone
    private let mutationID: @Sendable () -> UUID

    init(
        record: @escaping @Sendable (SnapRecordCommand) async throws -> SnapRecordReceipt,
        now: @escaping @Sendable () -> Date = Date.init,
        timeZone: @escaping @Sendable () -> TimeZone = { .current },
        mutationID: @escaping @Sendable () -> UUID = UUID.init,
        allowsPhotos: Bool = false,
        layout: Layout = .combined,
        publishPhoto: (@Sendable (NormalizedJpeg) async throws -> UUID)? = nil
    ) {
        self.record = record
        self.publishPhoto = publishPhoto
        self.now = now
        self.timeZone = timeZone
        self.mutationID = mutationID
        self.allowsPhotos = allowsPhotos
        self.layout = layout
        if allowsPhotos {
            self.phase = .source
            self.focusTarget = .sourceHeader
        } else if layout == .combined {
            self.phase = .details
            self.focusTarget = .categoryHeader
        } else {
            self.phase = .category
            self.focusTarget = .categoryHeader
        }
    }

    var amountText: String {
        let amount = Int64(digits) ?? 0
        return amount.wonText
    }

    var canSubmit: Bool {
        guard !isSubmitting, !succeeded, failure == nil || failure?.isRetryable == true,
              selectedCategory != nil,
              let amount = Int64(digits) else { return false }
        return (1...999_999_999).contains(amount)
            && Self.serverTimeZoneIdentifier(timeZone(), at: now()) != nil
    }

    var needsCategoryPrompt: Bool {
        phase == .details && selectedCategory == nil
    }

    var submitTitle: String {
        if failure?.isRetryable == true { return "재시도" }
        if !photoQueue.photos.isEmpty, photoQueue.index + 1 < photoQueue.photos.count {
            return "다음"
        }
        return "완료"
    }

    var requiresAbandonConfirmation: Bool {
        frozenCommand != nil && failure?.isRetryable == true && !succeeded
    }

    var hasTerminalFailure: Bool {
        failure != nil && failure?.isRetryable == false
    }

    var accessibilityAnnouncement: String {
        switch focusTarget {
        case .sourceHeader: "사진 선택 단계"
        case .categoryHeader:
            if layout == .combined && selectedCategory == nil {
                "카테고리를 선택하세요"
            } else if layout == .combined {
                "카테고리와 금액 입력"
            } else {
                "카테고리 선택 단계"
            }
        case .amountHeader: layout == .combined ? "카테고리와 금액 입력" : "금액 입력 단계"
        case .retryAction: "저장 결과를 확인하지 못했습니다"
        }
    }

    func select(_ category: SnapCategory) {
        guard !isSubmitting, frozenCommand == nil else { return }
        selectedCategory = category
        if layout == .staged {
            phase = .amount
            focusTarget = .amountHeader
        } else {
            focusTarget = .amountHeader
        }
    }

    func skipPhotos() {
        guard !isSubmitting, frozenCommand == nil else { return }
        enterDetails()
    }

    func prepareNextPhoto() {
        guard !photoQueue.isFinished else { return }
        frozenCommand = nil
        succeeded = false
        failure = nil
        publishTask = nil
        digits = ""
        selectedCategory = nil
        startPrefetch()
        enterDetails()
    }

    func clearAmount() {
        guard !isSubmitting, frozenCommand == nil else { return }
        digits = ""
    }

    func attach(_ photos: [NormalizedJpeg]) {
        guard !isSubmitting, frozenCommand == nil else { return }
        photoQueue.enqueue(photos)
        startPrefetch()
        enterDetails()
    }

    func goBack() {
        guard !isSubmitting, frozenCommand == nil else { return }
        if layout == .combined {
            guard allowsPhotos else { return }
            phase = .source
            focusTarget = .sourceHeader
            return
        }
        phase = .category
        focusTarget = .categoryHeader
    }

    func appendDigit(_ digit: Int) {
        guard !isSubmitting, frozenCommand == nil, (0...9).contains(digit) else { return }
        let candidate = digits == "0" ? String(digit) : digits + String(digit)
        guard let amount = Int64(candidate), amount <= 999_999_999 else { return }
        digits = candidate
    }

    func deleteDigit() {
        guard !isSubmitting, frozenCommand == nil, !digits.isEmpty else { return }
        digits.removeLast()
    }

    func submit() async -> SnapRecordReceipt? {
        guard !isSubmitting, !succeeded, failure == nil || failure?.isRetryable == true else { return nil }
        let command: SnapRecordCommand
        if let frozenCommand {
            command = frozenCommand
        } else {
            guard
                let selectedCategory,
                let amount = Int64(digits),
                (1...999_999_999).contains(amount)
            else { return nil }
            let commandDate = now()
            let zone = timeZone()
            guard let zoneIdentifier = Self.serverTimeZoneIdentifier(zone, at: commandDate) else {
                return nil
            }
            isSubmitting = true
            failure = nil
            let imageRef: UUID?
            do {
                imageRef = try await resolvedImageRef()
            } catch let error as SnapRecordError {
                isSubmitting = false
                failure = error
                if error.isRetryable { focusTarget = .retryAction }
                return nil
            } catch {
                isSubmitting = false
                failure = .transportFailure
                focusTarget = .retryAction
                return nil
            }
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = zone
            formatter.dateFormat = "yyyy-MM-dd"
            command = SnapRecordCommand(
                clientMutationId: mutationID().uuidString.lowercased(),
                localDay: formatter.string(from: commandDate),
                timeZone: zoneIdentifier,
                category: selectedCategory,
                amountWon: amount,
                imageRef: imageRef
            )
            frozenCommand = command
        }

        isSubmitting = true
        failure = nil
        defer { isSubmitting = false }
        do {
            let receipt = try await record(command)
            succeeded = true
            if !photoQueue.photos.isEmpty {
                photoQueue.markCurrentSaved(receipt)
            }
            return receipt
        } catch let error as SnapRecordError {
            failure = error
            if error.isRetryable { focusTarget = .retryAction }
            return nil
        } catch {
            failure = .transportFailure
            focusTarget = .retryAction
            return nil
        }
    }

    private func enterDetails() {
        if layout == .combined {
            phase = .details
        } else {
            phase = .category
        }
        focusTarget = .categoryHeader
    }

    private func startPrefetch() {
        guard publishTask == nil, let currentPhoto = photoQueue.current, let publishPhoto else { return }
        publishTask = Task {
            try await publishPhoto(currentPhoto)
        }
    }

    private func resolvedImageRef() async throws -> UUID? {
        if let publishTask {
            do {
                return try await publishTask.value
            } catch {
                self.publishTask = nil
                throw error
            }
        }
        guard let currentPhoto = photoQueue.current, let publishPhoto else { return nil }
        let task = Task { try await publishPhoto(currentPhoto) }
        publishTask = task
        return try await task.value
    }

    private static func serverTimeZoneIdentifier(_ zone: TimeZone, at date: Date) -> String? {
        if zone.secondsFromGMT(for: date) == 0,
           zone.identifier == "GMT" || zone.identifier == "UTC" {
            return "UTC"
        }
        guard zone.identifier.contains("/"),
              TimeZone.knownTimeZoneIdentifiers.contains(zone.identifier) else { return nil }
        return zone.identifier
    }
}

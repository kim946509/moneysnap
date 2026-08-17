import Foundation
import Observation

@MainActor
@Observable
final class SnapCaptureModel {
    enum Phase: Equatable, Sendable {
        case source
        case category
        case amount
    }

    enum FocusTarget: Hashable, Sendable {
        case sourceHeader
        case categoryHeader
        case amountHeader
        case retryAction
    }

    private(set) var phase: Phase
    let photoQueue = PhotoQueueModel()
    private(set) var selectedCategory: SnapCategory?
    private(set) var failure: SnapRecordError?
    private(set) var isSubmitting = false
    private(set) var focusTarget: FocusTarget = .categoryHeader

    private var digits = ""
    private var frozenCommand: SnapRecordCommand?
    private var succeeded = false
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
        publishPhoto: (@Sendable (NormalizedJpeg) async throws -> UUID)? = nil
    ) {
        self.record = record
        self.publishPhoto = publishPhoto
        self.now = now
        self.timeZone = timeZone
        self.mutationID = mutationID
        self.phase = allowsPhotos ? .source : .category
        self.focusTarget = allowsPhotos ? .sourceHeader : .categoryHeader
    }

    var amountText: String {
        let amount = Int64(digits) ?? 0
        return amount.wonText
    }

    var canSubmit: Bool {
        guard !isSubmitting, !succeeded, failure == nil || failure?.isRetryable == true,
              let amount = Int64(digits) else { return false }
        return (1...999_999_999).contains(amount)
            && Self.serverTimeZoneIdentifier(timeZone(), at: now()) != nil
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
        case .categoryHeader: "카테고리 선택 단계"
        case .amountHeader: "금액 입력 단계"
        case .retryAction: "저장 결과를 확인하지 못했습니다"
        }
    }

    func select(_ category: SnapCategory) {
        guard !isSubmitting, frozenCommand == nil else { return }
        selectedCategory = category
        phase = .amount
        focusTarget = .amountHeader
    }

    func skipPhotos() {
        guard !isSubmitting, frozenCommand == nil else { return }
        phase = .category
        focusTarget = .categoryHeader
    }

    func prepareNextPhoto() {
        guard !photoQueue.isFinished else { return }
        frozenCommand = nil
        succeeded = false
        failure = nil
        phase = .category
        focusTarget = .categoryHeader
    }

    func attach(_ photos: [NormalizedJpeg]) {
        guard !isSubmitting, frozenCommand == nil else { return }
        photoQueue.enqueue(photos)
        phase = .category
        focusTarget = .categoryHeader
    }

    func goBack() {
        guard !isSubmitting, frozenCommand == nil else { return }
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
                if let currentPhoto = photoQueue.current, let publishPhoto {
                    imageRef = try await publishPhoto(currentPhoto)
                } else {
                    imageRef = nil
                }
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

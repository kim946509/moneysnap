import Foundation

struct SnapRecordCommand: Codable, Equatable, Sendable {
    let clientMutationId: String
    let localDay: String
    let timeZone: String
    let category: SnapCategory
    let amountWon: Int64
}

struct SnapRecordReceipt: Equatable, Sendable {
    let id: UUID
    let category: SnapCategory
    let amountWon: Int64
    let localDay: String
    let createdAt: Date
}

enum SnapRecordError: Error, Equatable, Sendable {
    case invalidRequest(correlationID: String)
    case sessionRejected(correlationID: String?)
    case mutationConflict(correlationID: String)
    case serverFailure(correlationID: String?)
    case transportFailure
    case malformedResponse

    var isRetryable: Bool {
        switch self {
        case .serverFailure, .transportFailure, .malformedResponse:
            true
        case .invalidRequest, .sessionRejected, .mutationConflict:
            false
        }
    }
}

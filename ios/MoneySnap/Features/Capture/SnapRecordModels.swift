import Foundation

struct SnapRecordCommand: Codable, Equatable, Sendable {
    let clientMutationId: String
    let localDay: String
    let timeZone: String
    let category: SnapCategory
    let amountWon: Int64
    var imageRef: UUID? = nil

    enum CodingKeys: String, CodingKey {
        case clientMutationId, localDay, timeZone, category, amountWon, imageRef
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(clientMutationId, forKey: .clientMutationId)
        try container.encode(localDay, forKey: .localDay)
        try container.encode(timeZone, forKey: .timeZone)
        try container.encode(category, forKey: .category)
        try container.encode(amountWon, forKey: .amountWon)
        try container.encodeIfPresent(imageRef, forKey: .imageRef)
    }
}

struct SnapRecordReceipt: Equatable, Sendable {
    let id: UUID
    let category: SnapCategory
    let amountWon: Int64
    let localDay: String
    let createdAt: Date
}

struct SnapDetail: Equatable, Sendable {
    let id: UUID
    let category: SnapCategory
    let amountWon: Int64
    let localDay: String
    let createdAt: Date
    let updatedAt: Date
    let version: Int
}

struct SnapReviseCommand: Codable, Equatable, Sendable {
    let clientMutationId: String
    let expectedVersion: Int
    let category: SnapCategory
    let amountWon: Int64
}

enum SnapRecordError: Error, Equatable, Sendable {
    case invalidRequest(correlationID: String)
    case sessionRejected(correlationID: String?)
    case mutationConflict(correlationID: String)
    case versionConflict(correlationID: String)
    case notAccessible(correlationID: String)
    case serverFailure(correlationID: String?)
    case transportFailure
    case malformedResponse

    var isRetryable: Bool {
        switch self {
        case .serverFailure, .transportFailure, .malformedResponse:
            true
        case .invalidRequest, .sessionRejected, .mutationConflict, .versionConflict, .notAccessible:
            false
        }
    }
}

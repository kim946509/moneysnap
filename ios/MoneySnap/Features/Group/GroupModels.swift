import Foundation

struct MoneySnapGroup: Identifiable, Equatable, Sendable, Decodable {
    let id: UUID
    let name: String
    let amountVisible: Bool
    let role: Role
    let createdAt: Date

    enum Role: String, Equatable, Sendable, Decodable {
        case owner
        case member
    }
}

struct GroupList: Equatable, Sendable, Decodable {
    let groups: [MoneySnapGroup]
}

struct GroupCreateCommand: Encodable, Equatable, Sendable {
    let clientMutationId: String
    let name: String
    let amountVisible: Bool
}

import Foundation

struct AppleSignInCredential: Encodable, Equatable, Sendable {
    let identityToken: String
    let authorizationCode: String
    let nonce: String
}

struct AuthenticationSession: Codable, Equatable, Sendable {
    let accessToken: String
    let accessExpiresAt: Date
    let refreshToken: String
    let refreshExpiresAt: Date
}

enum AuthenticationPhase: Equatable, Sendable {
    case restoring
    case signedOut
    case authenticated(AuthenticationSession)
    case restoreFailed
}

enum AuthenticationIssue: Equatable, Sendable {
    case signInFailed
    case logoutFailed
    case accountDeletionFailed
    case localSessionCleanupFailed
    case localSessionPersistenceFailed
}

enum AuthenticationClientError: Error, Equatable, Sendable {
    case sessionRejected
    case temporarilyUnavailable
    case invalidResponse
}

protocol AuthenticationAPI: Sendable {
    func signIn(with credential: AppleSignInCredential) async throws -> AuthenticationSession
    func refresh(_ refreshToken: String) async throws -> AuthenticationSession
    func logout(accessToken: String) async throws
    func deleteAccount(
        accessToken: String,
        credential: AppleSignInCredential
    ) async throws
}

protocol SessionStore: Sendable {
    func load() async throws -> AuthenticationSession?
    func save(_ session: AuthenticationSession) async throws
    func clear() async throws
}

import Foundation
import Observation

@MainActor
@Observable
final class AuthenticationModel {
    private(set) var phase: AuthenticationPhase
    private(set) var issue: AuthenticationIssue?
    private(set) var isWorking = false

    private let api: any AuthenticationAPI
    private let store: any SessionStore
    private let now: () -> Date
    private var refreshTask: Task<AuthenticationSession, Error>?
    private var operationCount = 0
    private var destructiveOperationInProgress = false

    init(
        api: any AuthenticationAPI,
        store: any SessionStore,
        initialPhase: AuthenticationPhase = .restoring,
        now: @escaping () -> Date = Date.init
    ) {
        self.api = api
        self.store = store
        self.phase = initialPhase
        self.now = now
    }

    func restore() async {
        guard !isWorking else { return }
        beginOperation()
        defer { endOperation() }
        phase = .restoring
        issue = nil
        do {
            guard let stored = try await store.load() else {
                phase = .signedOut
                return
            }
            if stored.accessExpiresAt > now().addingTimeInterval(30) {
                phase = .authenticated(stored)
                return
            }
            _ = try await refresh(stored)
        } catch AuthenticationClientError.sessionRejected {
            await completeLocalSignOut()
        } catch {
            phase = .restoreFailed
        }
    }

    func signIn(with credential: AppleSignInCredential) async {
        guard phase == .signedOut, !isWorking else { return }
        beginOperation()
        issue = nil
        defer { endOperation() }
        do {
            let session = try await api.signIn(with: credential)
            try await store.save(session)
            phase = .authenticated(session)
        } catch {
            issue = .signInFailed
        }
    }

    func accessTokenForRequest() async throws -> String {
        guard case let .authenticated(session) = phase else {
            throw AuthenticationClientError.sessionRejected
        }
        if isWorking, refreshTask == nil {
            throw AuthenticationClientError.temporarilyUnavailable
        }
        let ownsRefresh = session.accessExpiresAt <= now().addingTimeInterval(30) && refreshTask == nil
        if ownsRefresh {
            guard !isWorking else { throw AuthenticationClientError.temporarilyUnavailable }
            beginOperation()
        }
        defer {
            if ownsRefresh { endOperation() }
        }
        return try await accessToken(for: session)
    }

    func handleSessionRejection(for accessToken: String) async {
        guard case let .authenticated(session) = phase else { return }
        guard session.accessToken == accessToken else { return }
        await completeLocalSignOut()
    }

    private func accessToken(for session: AuthenticationSession) async throws -> String {
        if session.accessExpiresAt > now().addingTimeInterval(30) {
            return session.accessToken
        }
        do {
            let refreshed = try await refresh(session)
            return refreshed.accessToken
        } catch AuthenticationClientError.sessionRejected {
            await completeLocalSignOut()
            throw AuthenticationClientError.sessionRejected
        } catch {
            throw error
        }
    }

    func logout() async {
        guard case let .authenticated(session) = phase else { return }
        guard !destructiveOperationInProgress else { return }
        guard !isWorking || refreshTask != nil else { return }
        destructiveOperationInProgress = true
        beginOperation()
        issue = nil
        defer {
            destructiveOperationInProgress = false
            endOperation()
        }
        do {
            let accessToken = try await accessToken(for: session)
            try await api.logout(accessToken: accessToken)
            await completeLocalSignOut()
        } catch AuthenticationClientError.sessionRejected {
            await completeLocalSignOut()
        } catch {
            issue = .logoutFailed
        }
    }

    func deleteAccount(with credential: AppleSignInCredential) async {
        guard case let .authenticated(session) = phase else { return }
        guard !destructiveOperationInProgress else { return }
        guard !isWorking || refreshTask != nil else { return }
        destructiveOperationInProgress = true
        beginOperation()
        issue = nil
        defer {
            destructiveOperationInProgress = false
            endOperation()
        }
        do {
            let accessToken = try await accessToken(for: session)
            try await api.deleteAccount(
                accessToken: accessToken,
                credential: credential
            )
            await completeLocalSignOut()
        } catch AuthenticationClientError.sessionRejected {
            await completeLocalSignOut()
        } catch AuthenticationClientError.reauthenticationRejected {
            issue = .accountReauthenticationFailed
        } catch {
            issue = .accountDeletionFailed
        }
    }

    func reportAppleAuthorizationFailure() {
        issue = .signInFailed
    }

    func reportAccountDeletionAuthorizationFailure() {
        issue = .accountReauthenticationFailed
    }

    func clearIssue() {
        issue = nil
    }

    private func completeLocalSignOut() async {
        phase = .signedOut
        do {
            try await store.clear()
        } catch {
            issue = .localSessionCleanupFailed
        }
    }

    private func refresh(_ session: AuthenticationSession) async throws -> AuthenticationSession {
        if let refreshTask {
            return try await refreshTask.value
        }
        let task = Task {
            let refreshed = try await api.refresh(session.refreshToken)
            guard phase == .authenticated(session) else {
                throw AuthenticationClientError.sessionRejected
            }
            do {
                try await store.save(refreshed)
            } catch {
                try? await store.clear()
                phase = .restoreFailed
                issue = .localSessionPersistenceFailed
                throw AuthenticationClientError.localSessionPersistenceFailed
            }
            guard phase == .authenticated(session) else {
                try? await store.clear()
                throw AuthenticationClientError.sessionRejected
            }
            phase = .authenticated(refreshed)
            return refreshed
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func beginOperation() {
        operationCount += 1
        isWorking = true
    }

    private func endOperation() {
        operationCount -= 1
        isWorking = operationCount > 0
    }
}

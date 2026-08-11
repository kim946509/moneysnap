import Foundation
import Testing
@testable import MoneySnap

@MainActor
struct AuthenticationModelTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func restoreShowsSignInWhenTheKeychainHasNoSession() async {
        let model = AuthenticationModel(
            api: StubAuthenticationAPI(),
            store: MemorySessionStore(),
            now: { now }
        )

        await model.restore()

        #expect(model.phase == .signedOut)
    }

    @Test
    func restoreUsesAStillValidAccessSession() async {
        let stored = session(access: "stored-access", accessExpiresIn: 300)
        let model = AuthenticationModel(
            api: StubAuthenticationAPI(),
            store: MemorySessionStore(session: stored),
            now: { now }
        )

        await model.restore()

        #expect(model.phase == .authenticated(stored))
    }

    @Test
    func restoreDoesNotRefreshAStillValidAccessSession() async {
        let api = StubAuthenticationAPI()
        let model = AuthenticationModel(
            api: api,
            store: MemorySessionStore(session: session(accessExpiresIn: 300)),
            now: { now }
        )

        await model.restore()

        #expect(await api.refreshCallCount == 0)
    }

    @Test
    func restoreRotatesAnExpiredAccessSession() async {
        let rotated = session(access: "rotated-access", refresh: "rotated-refresh", accessExpiresIn: 900)
        let model = AuthenticationModel(
            api: StubAuthenticationAPI(refreshSession: rotated),
            store: MemorySessionStore(session: session(accessExpiresIn: -1)),
            now: { now }
        )

        await model.restore()

        #expect(model.phase == .authenticated(rotated))
    }

    @Test
    func restorePersistsTheRotatedSession() async throws {
        let rotated = session(access: "rotated-access", refresh: "rotated-refresh", accessExpiresIn: 900)
        let store = MemorySessionStore(session: session(accessExpiresIn: -1))
        let model = AuthenticationModel(
            api: StubAuthenticationAPI(refreshSession: rotated),
            store: store,
            now: { now }
        )

        await model.restore()

        #expect(try await store.load() == rotated)
    }

    @Test
    func rejectedRefreshReturnsToSignIn() async {
        let model = AuthenticationModel(
            api: StubAuthenticationAPI(refreshError: .sessionRejected),
            store: MemorySessionStore(session: session(accessExpiresIn: -1)),
            now: { now }
        )

        await model.restore()

        #expect(model.phase == .signedOut)
    }

    @Test
    func rejectedRefreshClearsTheKeychainSession() async throws {
        let store = MemorySessionStore(session: session(accessExpiresIn: -1))
        let model = AuthenticationModel(
            api: StubAuthenticationAPI(refreshError: .sessionRejected),
            store: store,
            now: { now }
        )

        await model.restore()

        #expect(try await store.load() == nil)
    }

    @Test
    func rejectedRefreshReportsAKeychainCleanupFailure() async {
        let stored = session(accessExpiresIn: -1)
        let model = AuthenticationModel(
            api: StubAuthenticationAPI(refreshError: .sessionRejected),
            store: MemorySessionStore(session: stored, failsToClear: true),
            now: { now }
        )

        await model.restore()

        #expect(model.issue == .localSessionCleanupFailed)
    }

    @Test
    func temporaryRefreshFailureShowsRetryInsteadOfSignIn() async {
        let stored = session(accessExpiresIn: -1)
        let model = AuthenticationModel(
            api: StubAuthenticationAPI(refreshError: .temporarilyUnavailable),
            store: MemorySessionStore(session: stored),
            now: { now }
        )

        await model.restore()

        #expect(model.phase == .restoreFailed)
    }

    @Test
    func temporaryRefreshFailurePreservesTheKeychainSession() async throws {
        let stored = session(accessExpiresIn: -1)
        let store = MemorySessionStore(session: stored)
        let model = AuthenticationModel(
            api: StubAuthenticationAPI(refreshError: .temporarilyUnavailable),
            store: store,
            now: { now }
        )

        await model.restore()

        #expect(try await store.load() == stored)
    }

    @Test
    func requestAccessRefreshesAnExpiredAuthenticatedSession() async throws {
        let rotated = session(access: "request-access", refresh: "request-refresh", accessExpiresIn: 900)
        let stored = session(accessExpiresIn: -1)
        let model = authenticatedModel(
            api: StubAuthenticationAPI(refreshSession: rotated),
            store: MemorySessionStore(session: stored),
            session: stored
        )

        let accessToken = try await model.accessTokenForRequest()

        #expect(accessToken == "request-access")
    }

    @Test
    func requestAccessPersistsTheRotatedAuthenticatedSession() async throws {
        let rotated = session(access: "request-access", refresh: "request-refresh", accessExpiresIn: 900)
        let stored = session(accessExpiresIn: -1)
        let store = MemorySessionStore(session: stored)
        let model = authenticatedModel(
            api: StubAuthenticationAPI(refreshSession: rotated),
            store: store,
            session: stored
        )

        _ = try await model.accessTokenForRequest()

        #expect(try await store.load() == rotated)
    }

    @Test
    func refreshDoesNotAuthenticateWhenKeychainSaveFails() async {
        let rotated = session(access: "rotated-access", refresh: "rotated-refresh")
        let stored = session(accessExpiresIn: -1)
        let model = authenticatedModel(
            api: StubAuthenticationAPI(refreshSession: rotated),
            store: MemorySessionStore(session: stored, failsToSave: true),
            session: stored
        )

        await #expect(throws: AuthenticationClientError.localSessionPersistenceFailed) {
            _ = try await model.accessTokenForRequest()
        }

        #expect(model.phase == .restoreFailed)
    }

    @Test
    func refreshRemovesTheStaleKeychainSessionWhenSaveFails() async throws {
        let stored = session(accessExpiresIn: -1)
        let store = MemorySessionStore(session: stored, failsToSave: true)
        let model = authenticatedModel(
            api: StubAuthenticationAPI(refreshSession: session(refresh: "rotated-refresh")),
            store: store,
            session: stored
        )

        await #expect(throws: AuthenticationClientError.localSessionPersistenceFailed) {
            _ = try await model.accessTokenForRequest()
        }

        #expect(try await store.load() == nil)
    }

    @Test
    func concurrentRequestAccessSharesOneRefreshRotation() async throws {
        let stored = session(accessExpiresIn: -1)
        let api = StubAuthenticationAPI(
            refreshSession: session(access: "rotated"),
            refreshDelayNanoseconds: 50_000_000
        )
        let model = authenticatedModel(
            api: api,
            store: MemorySessionStore(session: stored),
            session: stored
        )

        async let first = model.accessTokenForRequest()
        async let second = model.accessTokenForRequest()
        _ = try await first
        _ = try await second

        #expect(await api.refreshCallCount == 1)
    }

    @Test
    func successfulAppleSignInAuthenticatesTheApp() async {
        let signedIn = session(access: "signed-in-access")
        let model = AuthenticationModel(
            api: StubAuthenticationAPI(signInSession: signedIn),
            store: MemorySessionStore(),
            now: { now }
        )

        await model.signIn(with: .fixture)

        #expect(model.phase == .authenticated(signedIn))
    }

    @Test
    func successfulAppleSignInPersistsTheSession() async throws {
        let signedIn = session(access: "signed-in-access")
        let store = MemorySessionStore()
        let model = AuthenticationModel(
            api: StubAuthenticationAPI(signInSession: signedIn),
            store: store,
            now: { now }
        )

        await model.signIn(with: .fixture)

        #expect(try await store.load() == signedIn)
    }

    @Test
    func failedAppleSignInStaysSignedOutWithRetryFeedback() async {
        let model = AuthenticationModel(
            api: StubAuthenticationAPI(signInError: .sessionRejected),
            store: MemorySessionStore(),
            now: { now }
        )

        await model.signIn(with: .fixture)

        #expect(model.phase == .signedOut && model.issue == .signInFailed)
    }

    @Test
    func appleSignInDoesNotAuthenticateWhenKeychainSaveFails() async {
        let model = AuthenticationModel(
            api: StubAuthenticationAPI(signInSession: session(access: "unpersisted-access")),
            store: MemorySessionStore(failsToSave: true),
            initialPhase: .signedOut,
            now: { now }
        )

        await model.signIn(with: .fixture)

        #expect(model.phase == .signedOut)
    }

    @Test
    func concurrentAppleSignInRunsOneAuthorizationExchange() async {
        let api = StubAuthenticationAPI(signInDelayNanoseconds: 50_000_000)
        let model = AuthenticationModel(
            api: api,
            store: MemorySessionStore(),
            now: { now }
        )

        async let first: Void = model.signIn(with: .fixture)
        async let second: Void = model.signIn(with: .fixture)
        await first
        await second

        #expect(await api.signInCallCount == 1)
    }

    @Test
    func successfulLogoutClearsTheLocalSession() async throws {
        let stored = session()
        let store = MemorySessionStore(session: stored)
        let model = authenticatedModel(api: StubAuthenticationAPI(), store: store, session: stored)

        await model.logout()

        #expect(try await store.load() == nil)
    }

    @Test
    func successfulLogoutReturnsToSignIn() async {
        let stored = session()
        let model = authenticatedModel(
            api: StubAuthenticationAPI(),
            store: MemorySessionStore(session: stored),
            session: stored
        )

        await model.logout()

        #expect(model.phase == .signedOut)
    }

    @Test
    func temporaryLogoutFailureKeepsTheAuthenticatedSession() async {
        let stored = session()
        let model = authenticatedModel(
            api: StubAuthenticationAPI(logoutError: .temporarilyUnavailable),
            store: MemorySessionStore(session: stored),
            session: stored
        )

        await model.logout()

        #expect(model.phase == .authenticated(stored) && model.issue == .logoutFailed)
    }

    @Test
    func rejectedLogoutSessionReturnsToSignIn() async {
        let stored = session()
        let model = authenticatedModel(
            api: StubAuthenticationAPI(logoutError: .sessionRejected),
            store: MemorySessionStore(session: stored),
            session: stored
        )

        await model.logout()

        #expect(model.phase == .signedOut)
    }

    @Test
    func rejectedLogoutSessionClearsTheKeychain() async throws {
        let stored = session()
        let store = MemorySessionStore(session: stored)
        let model = authenticatedModel(
            api: StubAuthenticationAPI(logoutError: .sessionRejected),
            store: store,
            session: stored
        )

        await model.logout()

        #expect(try await store.load() == nil)
    }

    @Test
    func logoutRefreshesAnExpiredAccessTokenBeforeRevoking() async {
        let stored = session(accessExpiresIn: -1)
        let api = StubAuthenticationAPI(refreshSession: session(access: "rotated-logout"))
        let model = authenticatedModel(
            api: api,
            store: MemorySessionStore(session: stored),
            session: stored
        )

        await model.logout()

        #expect(await api.loggedOutAccessToken == "rotated-logout")
    }

    @Test
    func logoutDuringRefreshRevokesTheRotatedSession() async throws {
        let stored = session(accessExpiresIn: -1)
        let api = StubAuthenticationAPI(
            refreshSession: session(access: "rotated-logout"),
            refreshDelayNanoseconds: 50_000_000
        )
        let model = authenticatedModel(
            api: api,
            store: MemorySessionStore(session: stored),
            session: stored
        )

        async let access = model.accessTokenForRequest()
        async let logout: Void = model.logout()
        _ = try await access
        await logout

        #expect(await api.loggedOutAccessToken == "rotated-logout")
    }

    @Test
    func logoutDuringRefreshEndsSignedOut() async throws {
        let stored = session(accessExpiresIn: -1)
        let api = StubAuthenticationAPI(
            refreshSession: session(access: "rotated-logout"),
            refreshDelayNanoseconds: 50_000_000
        )
        let model = authenticatedModel(
            api: api,
            store: MemorySessionStore(session: stored),
            session: stored
        )

        async let access = model.accessTokenForRequest()
        async let logout: Void = model.logout()
        _ = try await access
        await logout

        #expect(model.phase == .signedOut)
    }

    @Test
    func duplicateLogoutDuringRefreshSendsOneLogoutCommand() async throws {
        let stored = session(accessExpiresIn: -1)
        let api = StubAuthenticationAPI(
            refreshSession: session(access: "rotated-logout"),
            refreshDelayNanoseconds: 50_000_000,
            logoutDelayNanoseconds: 50_000_000
        )
        let model = authenticatedModel(
            api: api,
            store: MemorySessionStore(session: stored),
            session: stored
        )

        async let access = model.accessTokenForRequest()
        async let firstLogout: Void = model.logout()
        async let secondLogout: Void = model.logout()
        _ = try await access
        await firstLogout
        await secondLogout

        #expect(await api.logoutCallCount == 1)
    }

    @Test
    func successfulAccountDeletionClearsTheLocalSession() async throws {
        let stored = session()
        let store = MemorySessionStore(session: stored)
        let model = authenticatedModel(api: StubAuthenticationAPI(), store: store, session: stored)

        await model.deleteAccount(with: .fixture)

        #expect(try await store.load() == nil)
    }

    @Test
    func accountDeletionRefreshesAnExpiredAccessTokenBeforeDeleting() async {
        let stored = session(accessExpiresIn: -1)
        let api = StubAuthenticationAPI(refreshSession: session(access: "rotated-delete-access"))
        let model = authenticatedModel(
            api: api,
            store: MemorySessionStore(session: stored),
            session: stored
        )

        await model.deleteAccount(with: .fixture)

        #expect(await api.deletedAccessToken == "rotated-delete-access")
    }

    @Test
    func accountDeletionDuringRefreshUsesTheRotatedSession() async throws {
        let stored = session(accessExpiresIn: -1)
        let api = StubAuthenticationAPI(
            refreshSession: session(access: "rotated-delete-access"),
            refreshDelayNanoseconds: 50_000_000
        )
        let model = authenticatedModel(
            api: api,
            store: MemorySessionStore(session: stored),
            session: stored
        )

        async let access = model.accessTokenForRequest()
        async let deletion: Void = model.deleteAccount(with: .fixture)
        _ = try await access
        await deletion

        #expect(await api.deletedAccessToken == "rotated-delete-access")
    }

    @Test
    func failedAccountDeletionKeepsTheAuthenticatedSession() async {
        let stored = session()
        let model = authenticatedModel(
            api: StubAuthenticationAPI(deleteError: .temporarilyUnavailable),
            store: MemorySessionStore(session: stored),
            session: stored
        )

        await model.deleteAccount(with: .fixture)

        #expect(model.phase == .authenticated(stored) && model.issue == .accountDeletionFailed)
    }

    @Test
    func rejectedAppleReauthenticationKeepsTheAuthenticatedSession() async {
        let stored = session()
        let model = authenticatedModel(
            api: StubAuthenticationAPI(deleteError: .reauthenticationRejected),
            store: MemorySessionStore(session: stored),
            session: stored
        )

        await model.deleteAccount(with: .fixture)

        #expect(model.phase == .authenticated(stored))
        #expect(model.issue == .accountReauthenticationFailed)
    }

    @Test
    func rejectedBearerDuringAccountDeletionSignsOut() async {
        let stored = session()
        let model = authenticatedModel(
            api: StubAuthenticationAPI(deleteError: .sessionRejected),
            store: MemorySessionStore(session: stored),
            session: stored
        )

        await model.deleteAccount(with: .fixture)

        #expect(model.phase == .signedOut)
    }

    @Test
    func committedAccountDeletionSignsOutWhenLocalCleanupFails() async {
        let stored = session()
        let model = authenticatedModel(
            api: StubAuthenticationAPI(),
            store: MemorySessionStore(session: stored, failsToClear: true),
            session: stored
        )

        await model.deleteAccount(with: .fixture)

        #expect(model.phase == .signedOut)
    }

    @Test
    func committedAccountDeletionReportsLocalCleanupFailure() async {
        let stored = session()
        let model = authenticatedModel(
            api: StubAuthenticationAPI(),
            store: MemorySessionStore(session: stored, failsToClear: true),
            session: stored
        )

        await model.deleteAccount(with: .fixture)

        #expect(model.issue == .localSessionCleanupFailed)
    }

    private func authenticatedModel(
        api: StubAuthenticationAPI,
        store: MemorySessionStore,
        session: AuthenticationSession
    ) -> AuthenticationModel {
        AuthenticationModel(
            api: api,
            store: store,
            initialPhase: .authenticated(session),
            now: { now }
        )
    }

    private func session(
        access: String = "access-token",
        refresh: String = "refresh-token",
        accessExpiresIn: TimeInterval = 900
    ) -> AuthenticationSession {
        AuthenticationSession(
            accessToken: access,
            accessExpiresAt: now.addingTimeInterval(accessExpiresIn),
            refreshToken: refresh,
            refreshExpiresAt: now.addingTimeInterval(180 * 24 * 60 * 60)
        )
    }
}

private extension AppleSignInCredential {
    static let fixture = AppleSignInCredential(
        identityToken: "apple-identity-token",
        authorizationCode: "apple-authorization-code",
        nonce: "request-nonce"
    )
}

private actor MemorySessionStore: SessionStore {
    private var session: AuthenticationSession?
    private let failsToSave: Bool
    private let failsToClear: Bool

    init(
        session: AuthenticationSession? = nil,
        failsToSave: Bool = false,
        failsToClear: Bool = false
    ) {
        self.session = session
        self.failsToSave = failsToSave
        self.failsToClear = failsToClear
    }

    func load() throws -> AuthenticationSession? {
        session
    }

    func save(_ session: AuthenticationSession) throws {
        if failsToSave {
            throw SessionStoreFixtureError.saveFailed
        }
        self.session = session
    }

    func clear() throws {
        if failsToClear {
            throw SessionStoreFixtureError.clearFailed
        }
        session = nil
    }
}

private enum SessionStoreFixtureError: Error {
    case saveFailed
    case clearFailed
}

private actor StubAuthenticationAPI: AuthenticationAPI {
    private let signInSession: AuthenticationSession?
    private let signInError: AuthenticationClientError?
    private let refreshSession: AuthenticationSession?
    private let refreshError: AuthenticationClientError?
    private let logoutError: AuthenticationClientError?
    private let deleteError: AuthenticationClientError?
    private let signInDelayNanoseconds: UInt64
    private let refreshDelayNanoseconds: UInt64
    private let logoutDelayNanoseconds: UInt64
    private(set) var signInCallCount = 0
    private(set) var refreshCallCount = 0
    private(set) var logoutCallCount = 0
    private(set) var deletedAccessToken: String?
    private(set) var loggedOutAccessToken: String?

    init(
        signInSession: AuthenticationSession? = nil,
        signInError: AuthenticationClientError? = nil,
        refreshSession: AuthenticationSession? = nil,
        refreshError: AuthenticationClientError? = nil,
        logoutError: AuthenticationClientError? = nil,
        deleteError: AuthenticationClientError? = nil,
        signInDelayNanoseconds: UInt64 = 0,
        refreshDelayNanoseconds: UInt64 = 0,
        logoutDelayNanoseconds: UInt64 = 0
    ) {
        self.signInSession = signInSession
        self.signInError = signInError
        self.refreshSession = refreshSession
        self.refreshError = refreshError
        self.logoutError = logoutError
        self.deleteError = deleteError
        self.signInDelayNanoseconds = signInDelayNanoseconds
        self.refreshDelayNanoseconds = refreshDelayNanoseconds
        self.logoutDelayNanoseconds = logoutDelayNanoseconds
    }

    func signIn(with credential: AppleSignInCredential) async throws -> AuthenticationSession {
        signInCallCount += 1
        if signInDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: signInDelayNanoseconds)
        }
        if let signInError { throw signInError }
        return signInSession ?? AuthenticationSession.fixture
    }

    func refresh(_ refreshToken: String) async throws -> AuthenticationSession {
        refreshCallCount += 1
        if refreshDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: refreshDelayNanoseconds)
        }
        if let refreshError { throw refreshError }
        return refreshSession ?? AuthenticationSession.fixture
    }

    func logout(accessToken: String) async throws {
        logoutCallCount += 1
        loggedOutAccessToken = accessToken
        if logoutDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: logoutDelayNanoseconds)
        }
        if let logoutError { throw logoutError }
    }

    func deleteAccount(accessToken: String, credential: AppleSignInCredential) throws {
        deletedAccessToken = accessToken
        if let deleteError { throw deleteError }
    }
}

private extension AuthenticationSession {
    static let fixture = AuthenticationSession(
        accessToken: "fixture-access",
        accessExpiresAt: Date(timeIntervalSince1970: 1_900_000_000),
        refreshToken: "fixture-refresh",
        refreshExpiresAt: Date(timeIntervalSince1970: 2_000_000_000)
    )
}
